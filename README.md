# More-Tea-Main

## Overview
`More-Tea-Main` is the main integration repository. It aggregates robot subsystems as git submodules and organizes them into:
- `other_ws/` for standalone/non-colcon components
- `ros2_ws/` for ROS 2 packages and full robot stack builds

## Requirements
- Ubuntu/Linux (Jetson-compatible setup is supported)
- Git with submodule support
- ROS 2 (recommended: Humble)
- `colcon` and `rosdep`
- Python 3.10+

## Dependency Installation
Install core tooling:

```bash
sudo apt update
sudo apt install -y \
	git \
	python3-colcon-common-extensions \
	python3-rosdep \
	python3-vcstool
```

Initialize rosdep once (if not already done):

```bash
sudo rosdep init
rosdep update
```

Install ROS 2 workspace dependencies:

```bash
cd ros2_ws
rosdep install --from-paths src --ignore-src -y --skip-keys "microxrcedds_agent micro_ros_agent"
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
