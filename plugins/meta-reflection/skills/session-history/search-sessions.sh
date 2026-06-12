#!/usr/bin/env bash
# search-sessions.sh - Search and browse Claude Code conversation history
# Usage: search-sessions.sh <command> [options]
#
# Commands:
#   list       List recent sessions (default: 20)
#   search     Search sessions by keyword in summaries/prompts
#   read       Read full conversation from a session
#   grep       Search within conversation content across sessions
#   projects   List all projects with session counts
#   prompts    Show recent prompts from history.jsonl
#
# Run with --help for detailed usage per command.

set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
HISTORY_FILE="${CLAUDE_DIR}/history.jsonl"
PROJECTS_DIR="${CLAUDE_DIR}/projects"

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
	BOLD='\033[1m' DIM='\033[2m' CYAN='\033[36m' GREEN='\033[32m' RESET='\033[0m'
else
	export BOLD='' DIM='' CYAN='' GREEN='' RESET=''
fi

usage() {
	cat <<'EOF'
Usage: search-sessions.sh <command> [options]

Commands:
  list [options]        List recent sessions
    -n NUM              Number of sessions (default: 20)
    -p PROJECT_PATH     Filter by project path (substring match)
    -b BRANCH           Filter by git branch (substring match)
    --after DATE        Only sessions after DATE (YYYY-MM-DD)
    --before DATE       Only sessions before DATE (YYYY-MM-DD)
    --json              Output as JSON

  search <keyword> [options]    Search sessions by keyword
    -n NUM              Max results (default: 20)
    -p PROJECT_PATH     Filter by project path
    --after DATE        Only sessions after DATE
    --before DATE       Only sessions before DATE
    --json              Output as JSON

  read <session-id>     Read full conversation from a session
    --raw               Output raw JSONL
    --json              Output as JSON array

  grep <pattern> [options]      Search within conversation content
    -n NUM              Max matching sessions (default: 10)
    -p PROJECT_PATH     Filter by project path
    --after DATE        Only sessions after DATE
    --context NUM       Lines of context around matches (default: 1)

  projects              List all projects with session counts

  prompts [options]     Show recent prompts from global history
    -n NUM              Number of prompts (default: 30)
    -p PROJECT_PATH     Filter by project path
    --after DATE        Only after DATE

  help                  Show this help
EOF
}

# Parse a date string to epoch seconds
date_to_epoch() {
	os_type="$(uname)"
	if [[ "${os_type}" == "Darwin" ]]; then
		date -j -f "%Y-%m-%d" "$1" "+%s" 2>/dev/null || echo 0
	else
		date -d "$1" "+%s" 2>/dev/null || echo 0
	fi
}

# Convert ISO timestamp to local readable format
format_ts() {
	local ts="$1"
	os_type="$(uname)"
	if [[ "${os_type}" == "Darwin" ]]; then
		# Handle both ISO format and epoch ms
		if [[ "${ts}" =~ ^[0-9]+$ ]]; then
			date -r "$((ts / 1000))" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "${ts}"
		else
			# Strip the T and everything after minutes
			echo "${ts}" | sed 's/T/ /;s/:[0-9][0-9]\.[0-9]*Z$//'
		fi
	else
		echo "${ts}" | sed 's/T/ /;s/:[0-9][0-9]\.[0-9]*Z$//'
	fi
}

# Collect all sessions from all project session-index.json files
collect_sessions() {
	local project_filter="${1:-}"
	local after_date="${2:-}"
	local before_date="${3:-}"
	local branch_filter="${4:-}"

	python3 -c "
import json, glob, os, sys

projects_dir = os.path.expanduser('~/.claude-axonius/projects')
sessions = []

for idx_file in glob.glob(os.path.join(projects_dir, '*/sessions-index.json')):
    try:
        with open(idx_file) as f:
            data = json.load(f)
    except:
        continue

    entries = data.get('entries', [])
    orig_path = data.get('originalPath', '')

    for entry in entries:
        project = entry.get('projectPath', orig_path)
        sessions.append({
            'sessionId': entry.get('sessionId', ''),
            'summary': entry.get('summary', ''),
            'firstPrompt': entry.get('firstPrompt', ''),
            'messageCount': entry.get('messageCount', 0),
            'created': entry.get('created', ''),
            'modified': entry.get('modified', ''),
            'gitBranch': entry.get('gitBranch', ''),
            'projectPath': project,
            'fullPath': entry.get('fullPath', ''),
        })

# Apply filters
project_filter = '''${project_filter}'''
after_date = '''${after_date}'''
before_date = '''${before_date}'''
branch_filter = '''${branch_filter}'''

if project_filter:
    sessions = [s for s in sessions if project_filter.lower() in s['projectPath'].lower()]
if branch_filter:
    sessions = [s for s in sessions if branch_filter.lower() in s.get('gitBranch', '').lower()]
if after_date:
    sessions = [s for s in sessions if s['created'] >= after_date]
if before_date:
    sessions = [s for s in sessions if s['created'] <= before_date]

# Sort by created descending
sessions.sort(key=lambda s: s.get('modified', s.get('created', '')), reverse=True)

json.dump(sessions, sys.stdout)
"
}

cmd_list() {
	local num=20 project="" after="" before="" branch="" as_json=false

	while [[ $# -gt 0 ]]; do
		case "$1" in
		-n)
			num="$2"
			shift 2
			;;
		-p)
			project="$2"
			shift 2
			;;
		-b)
			branch="$2"
			shift 2
			;;
		--after)
			after="$2"
			shift 2
			;;
		--before)
			before="$2"
			shift 2
			;;
		--json)
			as_json=true
			shift
			;;
		*) shift ;;
		esac
	done

	local sessions
	sessions=$(collect_sessions "${project}" "${after}" "${before}" "${branch}")

	if ${as_json}; then
		echo "${sessions}" | python3 -c "import json,sys; data=json.load(sys.stdin); print(json.dumps(data[:${num}], indent=2))"
		return
	fi

	echo "${sessions}" | python3 -c "
import json, sys
sessions = json.load(sys.stdin)[:${num}]
if not sessions:
    print('No sessions found.')
    sys.exit(0)

# Print table header
print(f'${BOLD}{\"Date\":<17} {\"Msgs\":>4}  {\"Branch\":<40} {\"Summary\":<50} {\"Session ID\":<36}${RESET}')
print('-' * 155)

for s in sessions:
    date = s['created'][:16].replace('T', ' ') if s.get('created') else 'unknown'
    msgs = str(s.get('messageCount', '?'))
    branch = (s.get('gitBranch') or '')[:40]
    summary = (s.get('summary') or s.get('firstPrompt', ''))[:50]
    sid = s.get('sessionId', '')[:36]
    print(f'{date:<17} {msgs:>4}  {branch:<40} {summary:<50} {sid:<36}')

print(f'\n${DIM}{len(sessions)} sessions shown${RESET}')
"
}

cmd_search() {
	local keyword="$1"
	shift || {
		echo "Usage: search <keyword> [options]"
		return 1
	}
	local num=20 project="" after="" before="" as_json=false

	while [[ $# -gt 0 ]]; do
		case "$1" in
		-n)
			num="$2"
			shift 2
			;;
		-p)
			project="$2"
			shift 2
			;;
		--after)
			after="$2"
			shift 2
			;;
		--before)
			before="$2"
			shift 2
			;;
		--json)
			as_json=true
			shift
			;;
		*) shift ;;
		esac
	done

	local sessions
	sessions=$(collect_sessions "${project}" "${after}" "${before}" "")

	# Filter by keyword
	local filtered
	filtered=$(echo "${sessions}" | python3 -c "
import json, sys
keyword = '''${keyword}'''.lower()
sessions = json.load(sys.stdin)
matches = []
for s in sessions:
    searchable = ' '.join([
        s.get('summary', ''),
        s.get('firstPrompt', ''),
        s.get('gitBranch', ''),
    ]).lower()
    if keyword in searchable:
        matches.append(s)
json.dump(matches[:${num}], sys.stdout)
")

	if ${as_json}; then
		echo "${filtered}" | python3 -m json.tool
		return
	fi

	echo "${filtered}" | python3 -c "
import json, sys
sessions = json.load(sys.stdin)
if not sessions:
    print('No matching sessions found.')
    sys.exit(0)

print(f'${BOLD}{\"Date\":<17} {\"Msgs\":>4}  {\"Branch\":<40} {\"Summary\":<50} {\"Session ID\":<36}${RESET}')
print('-' * 155)

for s in sessions:
    date = s['created'][:16].replace('T', ' ') if s.get('created') else 'unknown'
    msgs = str(s.get('messageCount', '?'))
    branch = (s.get('gitBranch') or '')[:40]
    summary = (s.get('summary') or s.get('firstPrompt', ''))[:50]
    sid = s.get('sessionId', '')[:36]
    print(f'{date:<17} {msgs:>4}  {branch:<40} {summary:<50} {sid:<36}')

print(f'\n${DIM}{len(sessions)} matches${RESET}')
"
}

cmd_read() {
	local session_id="$1"
	shift || {
		echo "Usage: read <session-id>"
		return 1
	}
	local raw=false as_json=false

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--raw)
			raw=true
			shift
			;;
		--json)
			as_json=true
			shift
			;;
		*) shift ;;
		esac
	done

	# Find the session file
	local session_file
	session_file=$(find "${PROJECTS_DIR}" -name "${session_id}.jsonl" -type f 2>/dev/null | head -1)

	if [[ -z "${session_file}" ]]; then
		# Also check subdirectories (session dirs)
		session_file=$(find "${PROJECTS_DIR}" -path "*/${session_id}/*.jsonl" -type f 2>/dev/null | head -1)
	fi

	if [[ -z "${session_file}" ]]; then
		echo "Session not found: ${session_id}"
		return 1
	fi

	if ${raw}; then
		cat "${session_file}"
		return
	fi

	python3 -c "
import json, sys

as_json = ${as_json}
messages = []

with open('${session_file}') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except:
            continue

        msg_type = obj.get('type', '')
        if msg_type not in ('user', 'assistant'):
            continue

        message = obj.get('message', {})
        role = message.get('role', msg_type)
        content = message.get('content', '')
        ts = obj.get('timestamp', '')

        # Skip tool_result user messages (just echoes of tool output)
        if role == 'user' and isinstance(content, list):
            has_tool_result = any(isinstance(b, dict) and b.get('type') == 'tool_result' for b in content)
            has_text = any(isinstance(b, dict) and b.get('type') == 'text' and b.get('text', '').strip() for b in content)
            if has_tool_result and not has_text:
                continue

        # Extract text from content
        if isinstance(content, list):
            text_parts = []
            for block in content:
                if isinstance(block, dict):
                    if block.get('type') == 'text':
                        t = block.get('text', '').strip()
                        if t:
                            text_parts.append(t)
                    elif block.get('type') == 'tool_use':
                        text_parts.append(f'[Tool: {block.get(\"name\", \"unknown\")}]')
                    # Skip tool_result and thinking blocks
                elif isinstance(block, str):
                    if block.strip():
                        text_parts.append(block.strip())
            text = '\n'.join(text_parts)
        elif isinstance(content, str):
            text = content
        else:
            text = str(content)

        text = text.strip()
        if not text:
            continue

        # Merge consecutive same-role messages
        if messages and messages[-1]['role'] == role:
            messages[-1]['text'] += '\n' + text
            continue

        messages.append({
            'role': role,
            'text': text,
            'timestamp': ts,
        })

if as_json:
    print(json.dumps(messages, indent=2))
else:
    for m in messages:
        role_label = '\$CYAN[User]\$RESET' if m['role'] == 'user' else '\$GREEN[Assistant]\$RESET'
        ts_str = m['timestamp'][:16].replace('T', ' ') if m.get('timestamp') else ''
        print(f'{role_label} \$DIM{ts_str}\$RESET')
        # Truncate very long messages
        text = m['text']
        if len(text) > 3000:
            text = text[:3000] + f'\n\$DIM... [{len(m[\"text\"])} chars total]\$RESET'
        print(text)
        print()
" 2>/dev/null
}

cmd_grep() {
	local pattern="$1"
	shift || {
		echo "Usage: grep <pattern> [options]"
		return 1
	}
	local num=10 project="" after=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		-n)
			num="$2"
			shift 2
			;;
		-p)
			project="$2"
			shift 2
			;;
		--after)
			after="$2"
			shift 2
			;;
		--context) shift 2 ;; # ctx parameter removed as it's unused
		*) shift ;;
		esac
	done

	local sessions
	sessions=$(collect_sessions "${project}" "${after}" "" "")

	echo "${sessions}" | python3 -c "
import json, sys, re, os

pattern = re.compile(r'''${pattern}''', re.IGNORECASE)
sessions = json.load(sys.stdin)
max_results = ${num}
found = 0

for s in sessions:
    if found >= max_results:
        break

    fp = s.get('fullPath', '')
    if not fp or not os.path.exists(fp):
        continue

    matches = []
    try:
        with open(fp) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except:
                    continue
                if obj.get('type') not in ('user', 'assistant'):
                    continue
                msg = obj.get('message', {})
                content = msg.get('content', '')
                if isinstance(content, list):
                    text = ' '.join(b.get('text', '') for b in content if isinstance(b, dict) and b.get('type') == 'text')
                elif isinstance(content, str):
                    text = content
                else:
                    continue
                if pattern.search(text):
                    role = msg.get('role', obj.get('type', ''))
                    # Extract matching line with context
                    for tline in text.split('\n'):
                        if pattern.search(tline):
                            matches.append((role, tline.strip()[:200]))
    except:
        continue

    if matches:
        found += 1
        date = s['created'][:16].replace('T', ' ') if s.get('created') else '?'
        summary = s.get('summary', s.get('firstPrompt', ''))[:60]
        sid = s.get('sessionId', '')
        print(f'\${BOLD}{date} | {summary}\${RESET}')
        print(f'\${DIM}  Session: {sid}  Branch: {s.get(\"gitBranch\", \"\")}\${RESET}')
        for role, line in matches[:5]:
            role_tag = '\${CYAN}[U]\${RESET}' if role == 'user' else '\${GREEN}[A]\${RESET}'
            print(f'  {role_tag} {line}')
        if len(matches) > 5:
            print(f'  \${DIM}... {len(matches)} total matches in this session\${RESET}')
        print()

if found == 0:
    print('No matches found.')
else:
    print(f'${DIM}{found} sessions with matches${RESET}')
"
}

cmd_projects() {
	python3 -c "
import json, glob, os

projects_dir = os.path.expanduser('~/.claude-axonius/projects')
projects = {}

for idx_file in sorted(glob.glob(os.path.join(projects_dir, '*/sessions-index.json'))):
    try:
        with open(idx_file) as f:
            data = json.load(f)
    except:
        continue
    entries = data.get('entries', [])
    orig_path = data.get('originalPath', '')
    if entries:
        project = entries[0].get('projectPath', orig_path)
    else:
        project = orig_path or os.path.basename(os.path.dirname(idx_file))

    total_msgs = sum(e.get('messageCount', 0) for e in entries)
    latest = max((e.get('modified', '') for e in entries), default='')
    projects[project] = {
        'sessions': len(entries),
        'messages': total_msgs,
        'latest': latest[:16].replace('T', ' ') if latest else '?',
    }

print(f'${BOLD}{\"Project\":<70} {\"Sessions\":>8} {\"Messages\":>8} {\"Last Active\":<17}${RESET}')
print('-' * 110)
for proj, info in sorted(projects.items(), key=lambda x: x[1]['latest'], reverse=True):
    short = proj.replace(os.path.expanduser('~'), '~')
    print(f'{short:<70} {info[\"sessions\"]:>8} {info[\"messages\"]:>8} {info[\"latest\"]:<17}')
"
}

cmd_prompts() {
    local num=30 project="" after=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		-n)
			num="$2"
			shift 2
			;;
		-p)
			project="$2"
			shift 2
			;;
		--after)
			after="$2"
			shift 2
			;;
		*) shift ;;
		esac
	done

	[[ -f "${HISTORY_FILE}" ]] || {
		echo "No history.jsonl found"
		return 1
	}

	python3 -c "
import json, sys, os

project_filter = '''${project}'''.lower()
after_filter = '''${after}'''
num = ${num}

prompts = []
with open(os.path.expanduser('~/.claude-axonius/history.jsonl')) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except:
            continue
        display = obj.get('display', '')
        if not display or display in ('exit', '/cost', '/config', '/model', '/clear'):
            continue

        project = obj.get('project', '')
        ts = obj.get('timestamp', 0)

        if project_filter and project_filter not in project.lower():
            continue

        prompts.append({
            'prompt': display[:120],
            'project': project.replace(os.path.expanduser('~'), '~'),
            'sessionId': obj.get('sessionId', ''),
            'timestamp': ts,
        })

# Sort by timestamp descending, take most recent
prompts.sort(key=lambda x: x['timestamp'], reverse=True)
prompts = prompts[:num]

print(f'${BOLD}{\"Date\":<17} {\"Project\":<50} {\"Prompt\":<80}${RESET}')
print('-' * 150)
for p in prompts:
    from datetime import datetime
    try:
        dt = datetime.fromtimestamp(p['timestamp'] / 1000).strftime('%Y-%m-%d %H:%M')
    except:
        dt = '?'
    proj = p['project'][-50:] if len(p['project']) > 50 else p['project']
    print(f'{dt:<17} {proj:<50} {p[\"prompt\"]:<80}')
"
}

# Main dispatch
case "${1:-help}" in
list)
	shift
	cmd_list "$@"
	;;
search)
	shift
	cmd_search "$@"
	;;
read)
	shift
	cmd_read "$@"
	;;
grep)
	shift
	cmd_grep "$@"
	;;
projects)
	shift
	cmd_projects "$@"
	;;
prompts)
	shift
	cmd_prompts "$@"
	;;
help | --help | -h) usage ;;
*)
	echo "Unknown command: $1"
	usage
	exit 1
	;;
esac
