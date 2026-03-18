# More-Tea-Main

## Overview
`More-Tea-Main` is the main integration repository. It aggregates robot subsystems as git submodules and organizes them into:
- `other_ws/` for standalone/non-colcon components
- `ros2_ws/` for ROS 2 packages and full robot stack builds

## Requirements
- Ubuntu 22.04
- ROS 2 Humble
- Git with submodule support
- Conda (Miniconda or Anaconda)

## Dependency Installation
Use the unified installer script (single flow for all dependencies across all submodules):

```bash
chmod +x scripts/install_dependencies.sh
./scripts/install_dependencies.sh
```

Optional arguments:

```bash
./scripts/install_dependencies.sh --env-name moretea --python 3.10
./scripts/install_dependencies.sh --dry-run
```

Note: ROS 2 Humble is used from the system installation (`/opt/ros/humble`). The script does not install ROS into Conda.

What the script installs/configures:
- System dependencies via `apt` (build tools, audio/video libs, ROS OpenCV bridge packages)
- `rosdep` initialization/update
- All git submodules (`sync` + `update --init --recursive`)
- One shared Conda environment for Python dependencies
- All Python packages needed by the project (PlatformIO, AI/voice, WebRTC, perception)
- SCServo static library build for `moretea_arm`
- Teensy udev rule copy (if present)
- ROS workspace dependency resolution (`rosdep install` in `ros2_ws`)

After script completion, in new terminals use:

```bash
source /opt/ros/$ROS_DISTRO/setup.bash
conda activate moretea
```

## Installation
Clone with submodules:

```bash
git clone --recursive <your-main-repo-url>
cd More-Tea-Main
```

If already cloned without submodules:

```bash
git submodule update --init --recursive
```

Build ROS 2 workspace:

```bash
cd ros2_ws
colcon build --symlink-install
source install/setup.bash
```

## Repository Structure
- `other_ws/head_motor/` – ESP32 head servo firmware (PlatformIO)
- `other_ws/llm_chat_robot/` – voice/LLM control scripts
- `other_ws/online_teleop/` – browser teleop/WebRTC service
- `ros2_ws/src/head_pubsub/` – face-tracking ROS 2 package
- `ros2_ws/src/moretea_arm/` – robot arm ROS 2 action package
- `ros2_ws/src/morerobot_docking/` – docking package
- `ros2_ws/src/linorobot2_humble/` – mobile base/nav stack
- `ros2_ws/src/linorobot2_hardware_hippo_esp32_fix/` – base firmware/hardware layer

## How to Use
Typical workflow:
1. Update submodules.
2. Build `ros2_ws` with `colcon`.
3. Source `ros2_ws/install/setup.bash`.
4. Launch required subsystems (base, perception, arm, docking, teleop) based on your scenario.

Example starting points:

```bash
# mobile base bringup (inside ros2_ws, after sourcing)
ros2 launch linorobot2_bringup bringup.launch.py

# face tracking
ros2 run head_pubsub face_tracker_node --ros-args -p headless:=true

# arm action server
ros2 run moretea_arm play_trajectory_server
```

## Submodule Management
Update all submodules to their tracked commits:

```bash
git submodule sync --recursive
git submodule update --init --recursive
```

Pull latest remote changes (when needed):

```bash
git pull --recurse-submodules
git submodule update --init --recursive
```

## Notes
- This repository is the orchestrator; each submodule has its own README with package-specific setup and usage.
- Build and runtime commands should be executed in the correct workspace (`other_ws` vs `ros2_ws`).
