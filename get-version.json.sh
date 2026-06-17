if ! command -v jq &> /dev/null; then
	printf "\033[1;31mPackage \"jq\" not found, please install it first.\033[0m\n"
	exit 1
fi
if ! command -v curl &> /dev/null; then
	printf "\033[1;31mPackage \"curl\" not found, please install it first.\033[0m\n"
	exit 1
fi

echo -n "Downloading version manifest..."
version_manifest_remote=${VERSION_MANIFEST_REMOTE:-"https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"}
version_manifest=$(curl -s --retry 3 --retry-delay 1 "$version_manifest_remote")
skip_release=0
skip_snapshot=0
skip_alpha=0
skip_beta=0
while [[ $# -gt 0 ]]; do
	case $1 in
		--skip-release)
			skip_release=1
			shift
			;;
		--skip-snapshot)
			skip_snapshot=1
			shift
			;;
		--skip-alpha)
			skip_alpha=1
			shift
			;;
		--skip-beta)
			skip_beta=1
			shift
			;;
		*)
			;;
	esac
done

if [ -z "$version_manifest" ] || [ "$(echo "$version_manifest" | jq '.versions' | jq -r 'type')" != "array" ]; then
	echo ""
	printf "\033[1;31mDownload version manifest failed.\033[0m\n"
	exit 1
fi
echo "Done"

mkdir -p "results"

success_count=0
fail_count=0
fail_filename="failed_$(date '+%Y%m%d_%H%M%S').txt"

while read -r item; do
	version_json_url=$(echo "$item" | jq -r '.url')
	version_id=$(echo "$item" | jq -r '.id')
	version_type=$(echo "$item" | jq -r '.type')
	if [ $version_type == "release" ] && [ $skip_release -eq 1 ]; then
		continue
	fi
	if [ $version_type == "snapshot" ] && [ $skip_snapshot -eq 1 ]; then
		continue
	fi
	if [ $version_type == "old_beta" ] && [ $skip_beta -eq 1 ]; then
		continue
	fi
	if [ $version_type == "old_alpha" ] && [ $skip_alpha -eq 1 ]; then
		continue
	fi
	echo -n "Downloading $version_id.json..."
	curl --retry 3 --retry-delay 1 -s "$version_json_url" > "results/$version_id.json"
	if [ $? -eq 0 ]; then
		echo "Done"
		((success_count++))
	else
		((fail_count++))
		printf "\033[1;31mFailed.\033[0m\n"
		echo "$version_id" >> "$fail_filename"
	fi
done < <(echo "$version_manifest" | jq -c ".versions[]")

echo ""
echo "Failed: $fail_count, Successed: $success_count"
if [ $fail_count -gt 0 ]; then
	echo "Failed tasks have been written to $fail_filename"
	exit 1
fi
