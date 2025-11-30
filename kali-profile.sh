DISTRO_NAME="Kali Linux (HCO Profile)"
DISTRO_ARCH="aarch64"

TARBALL_URL['aarch64']="https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-full.tar.xz"
TARBALL_SHA256['aarch64']="skip"

EXTRACT_USING="tar"

DISTRO_SETUP_COMMANDS=(
  "apt update -y"
  "apt upgrade -y"
)
