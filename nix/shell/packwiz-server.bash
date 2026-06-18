export PACKWIZ_SERVER_PID=""

pw() {
	if [[ -n "$PACKWIZ_SERVER_PID" ]] && kill -0 "$PACKWIZ_SERVER_PID" 2>/dev/null; then
		echo "packwiz-server already running (PID $PACKWIZ_SERVER_PID)"
		return 1
	fi

	if [[ -n "$1" ]]; then
		just pw "$1" &
	else
		just pw &
	fi
	PACKWIZ_SERVER_PID=$!

	echo "Started pw (PID $PACKWIZ_SERVER_PID)"
}

pw-stop() {
	if [[ -z "$PACKWIZ_SERVER_PID" ]]; then
		echo "No packwiz-server process recorded"
		return 1
	fi

	if kill -0 "$PACKWIZ_SERVER_PID" 2>/dev/null; then
		kill -- -"$PACKWIZ_SERVER_PID"
		wait "$PACKWIZ_SERVER_PID" 2>/dev/null || true
		echo "Stopped packwiz-server (PID $PACKWIZ_SERVER_PID)"
	fi

	PACKWIZ_SERVER_PID=""
}

_pw_complete() {
	local cur
	cur="${COMP_WORDS[COMP_CWORD]}"

	local refs
	readarray -t refs < <(
		git for-each-ref \
			--format='%(refname:short)' \
			refs/heads refs/remotes refs/tags 2>/dev/null
	)

	mapfile -t COMPREPLY < <(compgen -W "${refs[*]}" -- "$cur")
}

complete -F _pw_complete pw

trap 'pw-stop >/dev/null 2>&1' EXIT
