#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=false
ENV_NAME="moretea"
PYTHON_VERSION="3.10"
SYSTEM_ROS_DISTRO="humble"
SYSTEM_ROS_SETUP="/opt/ros/${SYSTEM_ROS_DISTRO}/setup.bash"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --env-name)
      ENV_NAME="$2"
      shift 2
      ;;
    --python)
      PYTHON_VERSION="$2"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage: scripts/install_dependencies.sh [options]

Options:
  --dry-run            Print commands without executing
  --env-name NAME      Conda env name (default: moretea)
  --python VERSION     Preferred Python version for conda env (default: 3.10)
  -h, --help           Show this help
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROS_WS="${REPO_ROOT}/ros2_ws"

run_cmd() {
  local cmd="$*"
  echo "+ ${cmd}"
  if [[ "${DRY_RUN}" == "false" ]]; then
    eval "${cmd}"
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' not found in PATH." >&2
    exit 1
  fi
}

if [[ "${DRY_RUN}" == "false" && ! -f "${SYSTEM_ROS_SETUP}" ]]; then
  echo "Error: system ROS 2 Humble not found at ${SYSTEM_ROS_SETUP}" >&2
  echo "Install ROS 2 Humble system-wide first, then re-run this script." >&2
  exit 1
fi

echo "[1/8] Installing system packages"
run_cmd "sudo apt update"
run_cmd "sudo apt install -y \
  git \
  python3-colcon-common-extensions \
  python3-rosdep \
  python3-vcstool \
  python3-pip \
  build-essential \
  cmake \
  libyaml-cpp-dev \
  ffmpeg \
  v4l-utils \
  portaudio19-dev \
  python3-pyaudio \
  screen \
  ros-${SYSTEM_ROS_DISTRO}-cv-bridge \
  ros-${SYSTEM_ROS_DISTRO}-vision-opencv \
  python3-opencv"

echo "[2/8] Initializing rosdep (idempotent)"
if [[ "${DRY_RUN}" == "true" ]]; then
  echo "+ if rosdep not initialized: sudo rosdep init"
else
  if [[ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]]; then
    sudo rosdep init
  fi
fi
run_cmd "rosdep update"

echo "[3/8] Syncing and updating submodules"
run_cmd "cd '${REPO_ROOT}' && git submodule sync --recursive"
if [[ "${DRY_RUN}" == "true" ]]; then
  echo "+ cd '${REPO_ROOT}' && git submodule update --init --recursive"
  echo "+ (fallback) cd '${REPO_ROOT}' && git submodule update --init"
else
  if ! (cd "${REPO_ROOT}" && git submodule update --init --recursive); then
    echo "Warning: recursive submodule update failed. Trying non-recursive update."
    if ! (cd "${REPO_ROOT}" && git submodule update --init); then
      echo "Warning: non-recursive submodule update also failed. Continuing with existing checkout."
    fi
  fi
fi

echo "[4/8] Preparing conda environment"
require_cmd conda

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "+ conda create -n '${ENV_NAME}' python='${PYTHON_VERSION}' -y (fallback to default python if unavailable)"
else
  if ! conda env list | awk '{print $1}' | grep -qx "${ENV_NAME}"; then
    if ! conda create -n "${ENV_NAME}" "python=${PYTHON_VERSION}" -y; then
      echo "Warning: python=${PYTHON_VERSION} unavailable, creating '${ENV_NAME}' with default python."
      conda create -n "${ENV_NAME}" -y
    fi
  else
    echo "Conda environment '${ENV_NAME}' already exists."
  fi
fi

echo "[5/8] Installing all Python dependencies into one conda env"
run_cmd "conda run -n '${ENV_NAME}' python -m pip install -U pip"
run_cmd "conda run -n '${ENV_NAME}' python -m pip install -U \
  platformio \
  openai \
  SpeechRecognition \
  pydub \
  sounddevice \
  numpy \
  scipy \
  typeguard \
  aiortc \
  aiohttp \
  ultralytics \
  torch"

echo "[6/8] Building SCServo static library for moretea_arm"
SCSERVO_DIR="${ROS_WS}/src/moretea_arm/include/SCServo_Linux"
if [[ -f "${SCSERVO_DIR}/CMakeLists.txt" ]]; then
  run_cmd "cd '${SCSERVO_DIR}' && cmake . && make -j\$(nproc)"
elif [[ -d "${SCSERVO_DIR}" ]]; then
  echo "Warning: ${SCSERVO_DIR} exists but CMakeLists.txt is missing. Skipping SCServo build."
else
  echo "Warning: ${SCSERVO_DIR} not found. Skipping SCServo build."
fi

echo "[7/8] Installing Teensy udev rule if present"
if [[ -f "${ROS_WS}/src/linorobot2_hardware_hippo_esp32_fix/firmware/00-teensy.rules" ]]; then
  run_cmd "sudo cp '${ROS_WS}/src/linorobot2_hardware_hippo_esp32_fix/firmware/00-teensy.rules' /etc/udev/rules.d/"
else
  echo "Info: Teensy rules file not found. Skipping."
fi

echo "[8/8] Installing ROS workspace dependencies via rosdep"
if [[ -d "${ROS_WS}" ]]; then
  ROSDEP_SKIP_KEYS="microxrcedds_agent micro_ros_agent ultralytics python3-opencv-contrib-python catkin gazebo_ros_pkgs"
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "+ source '${SYSTEM_ROS_SETUP}' && cd '${ROS_WS}' && rosdep install --from-paths src --ignore-src -r -y --skip-keys '${ROSDEP_SKIP_KEYS}'"
  else
    set +u
    # shellcheck disable=SC1090
    source "${SYSTEM_ROS_SETUP}"
    set -u
    (cd "${ROS_WS}" && rosdep install --from-paths src --ignore-src -r -y --skip-keys "${ROSDEP_SKIP_KEYS}")
  fi
else
  echo "Warning: ROS workspace '${ROS_WS}' not found. Skipping rosdep install from source paths."
fi

echo
  echo "Dependency installation flow completed."
  echo "Next terminal setup:"
  echo "  source ${SYSTEM_ROS_SETUP}"
  echo "  conda activate ${ENV_NAME}"
