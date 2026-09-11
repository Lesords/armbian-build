# Extension: plant-scripts
# @description Installs the BeagleBadge factory/plant test tooling into the
# image so a freshly flashed board is ready for station testing.
#
# Layout:
#   files/   -> /root/plant_scripts   (main script bundle)
#   mnt/     -> /mnt                  (self-compiled test binaries)
#   root/    -> /root                 (misc tools dropped in root's home)
# Any other directory added next to this file maps 1:1 to the same absolute
# path in the image, merged without touching existing target content.
# Editor leftovers (.viminfo, *.swp, *~) are never installed.
# Companion packages (python3, i2c-tools, evtest, ...) come from
# PACKAGE_LIST_BOARD in config/boards/beaglebadge.conf.

function post_customize_image__install_plant_scripts() {
	display_alert "$BOARD" "Installing plant test tooling" "info"

	# Main script bundle
	install -d "${SDCARD}/root/plant_scripts"
	run_host_command_logged cp -r "${EXTENSION_DIR}/files/." "${SDCARD}/root/plant_scripts/"
	chroot "${SDCARD}" /bin/bash -c "chmod -R +x /root/plant_scripts" || true

	# Directory-per-path mapping: <dir>/ -> /<dir>
	local dir name f
	for dir in "${EXTENSION_DIR}"/*/; do
		name="$(basename "${dir}")"
		[[ "${name}" == "files" ]] && continue

		install -d "${SDCARD}/${name}"
		for f in "${dir}"/*; do
			[[ -e "${f}" ]] || continue
			case "$(basename "${f}")" in
				.viminfo | *.sw? | *~) continue ;; # editor leftovers
			esac
			run_host_command_logged cp -r "${f}" "${SDCARD}/${name}/"
			chmod -R +x "${SDCARD}/${name}/$(basename "${f}")"
		done
	done
}
