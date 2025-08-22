#!/bin/bash
# Script to check for Docker base image updates
# Can be run locally for testing

set -euo pipefail

# Colors for output
#RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔍 Checking for Docker base image updates...${NC}"

# Initialize variables
has_updates=false
changelog=""

# Find all Dockerfiles
DOCKERFILES=$(find . -name "Dockerfile" -type f 2>/dev/null || true)

if [ -z "$DOCKERFILES" ]; then
    echo "No Dockerfiles found"
    exit 0
fi

for dockerfile in $DOCKERFILES; do
    echo -e "\n${GREEN}Checking: ${dockerfile}${NC}"

    # Process each FROM line
    while IFS= read -r line; do
        if [[ $line == FROM* ]]; then
            # Extract the base image
            if [[ $line == *" AS "* ]]; then
                base_image=$(echo "$line" | sed 's/ AS .*//' | awk '{print $2}')
            else
                base_image=$(echo "$line" | awk '{print $2}')
            fi

            # Skip scratch and other special images
            if [[ $base_image == "scratch" ]] || [[ $base_image == "busybox" ]]; then
                continue
            fi

            # Parse image name and tag
            if [[ $base_image == *:* ]]; then
                image_name=$(echo "$base_image" | cut -d: -f1)
                current_tag=$(echo "$base_image" | cut -d: -f2)
            else
                image_name=$base_image
                current_tag="latest"
            fi

            echo "  Current: $base_image"

            # Check for updates based on image type
            new_tag=""

            case "$image_name" in
                "golang")
                    # Extract Go version from current tag (e.g., 1.25 from 1.25-alpine3.21)
                    go_version=$(echo "$current_tag" | grep -oE '^[0-9]+\.[0-9]+' || echo "1.25")

                    # Check for latest Alpine version with this Go version
                    new_tag=$(curl -s "https://hub.docker.com/v2/repositories/library/golang/tags?page_size=100" 2>/dev/null | \
                        jq -r --arg v "$go_version" '.results[] | select(.name | test("^" + $v + "-alpine3\\.[0-9]+$")) | .name' | \
                        sort -V | tail -1)
                    ;;

                "alpine")
                    # Check for latest Alpine 3.x version
                    new_tag=$(curl -s "https://hub.docker.com/v2/repositories/library/alpine/tags?page_size=100" 2>/dev/null | \
                        jq -r '.results[] | select(.name | test("^3\\.[0-9]+$")) | .name' | \
                        sort -V | tail -1)
                    ;;

                "node")
                    # Check for latest Node LTS Alpine
                    node_major=$(echo "$current_tag" | grep -oE '^[0-9]+' || echo "20")
                    new_tag=$(curl -s "https://hub.docker.com/v2/repositories/library/node/tags?page_size=100" 2>/dev/null | \
                        jq -r --arg v "$node_major" '.results[] | select(.name | test("^" + $v + "\\.[0-9]+\\.[0-9]+-alpine3\\.[0-9]+$")) | .name' | \
                        sort -V | tail -1)
                    ;;

                "gcr.io/distroless/static"|"gcr.io/distroless/static-debian12")
                    # For distroless, we typically want nonroot
                    if [[ "$current_tag" != "nonroot" ]]; then
                        new_tag="nonroot"
                    fi
                    ;;

                *)
                    echo "    ⚠️  Unknown image type: $image_name"
                    ;;
            esac

            # Compare and report
            if [[ -n "$new_tag" ]] && [[ "$current_tag" != "$new_tag" ]]; then
                echo -e "    ${GREEN}✅ Update available: ${image_name}:${new_tag}${NC}"
                changelog="${changelog}✅ **${dockerfile#./}**: \`${base_image}\` → \`${image_name}:${new_tag}\`\n"
                has_updates=true
            else
                echo "    ✓ Up to date"
            fi
        fi
    done < "$dockerfile"
done

# Summary
echo -e "\n${YELLOW}════════════════════════════════════════${NC}"
if [ "$has_updates" = true ]; then
    echo -e "${GREEN}🎉 Updates available!${NC}\n"
    echo -e "$changelog"
    exit 0
else
    echo -e "${GREEN}✨ All Docker base images are up to date!${NC}"
    exit 0
fi
