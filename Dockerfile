# --- Dockerfile for running FAST-LIO with Robosense Airy LiDAR on ROS Noetic ---

# Use ROS Noetic
FROM osrf/ros:noetic-desktop-full

# Set environment variables for the build system
ENV ROS_DISTRO=noetic
ENV ROS_VERSION=1

SHELL ["/bin/bash", "-c"]

# 1. Install System Dependencies & Math Libraries for FAST-LIO
RUN apt-get update && apt-get install -y \
    git build-essential cmake wget nano \
    # Common dependencies for ROS and LiDAR processing (PCL)
    libpcap-dev libyaml-cpp-dev libpcl-dev \
    # Networking tools for testing and debugging
    iputils-ping net-tools iproute2 ethtool tcpdump \
    # FAST-LIO / SLAM Dependencies
    libgoogle-glog-dev libgflags-dev \
    libatlas-base-dev libsuitesparse-dev \
    # Standard ROS Noetic packages
    ros-noetic-roscpp ros-noetic-roslib ros-noetic-pcl-ros \
    ros-noetic-sensor-msgs ros-noetic-std-msgs \
    ros-noetic-tf ros-noetic-eigen-conversions \
    ros-noetic-message-generation ros-noetic-message-runtime \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Ceres Solver (Required by many FAST-LIO versions)
RUN git clone https://github.com/ceres-solver/ceres-solver.git && \
    cd ceres-solver && git checkout 1.14.0 && \
    mkdir build && cd build && cmake .. && make -j$(nproc) && make install && \
    cd ../.. && rm -rf ceres-solver

# Install Livox SDK system-wide
RUN git clone https://github.com/Livox-SDK/Livox-SDK.git /tmp/Livox-SDK && \
    cd /tmp/Livox-SDK/build && \
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && \
    make install && \
    echo "/usr/local/lib" >> /etc/ld.so.conf.d/livox.conf && \
    ldconfig && \
    rm -rf /tmp/Livox-SDK

# 3. Create Workspace
RUN mkdir -p /catkin_ws/src
WORKDIR /catkin_ws/src

# 4. Clone FAST-LIO ROS Package (RS-Airy branch)
RUN git clone --branch RS-Airy https://github.com/Ilyes-Origamist/robosense_fast_lio.git && \
    cd robosense_fast_lio && \
    git submodule update --init --recursive

# 5. Install drivers
# Clone the livox_ros_driver
RUN git clone https://github.com/Livox-SDK/livox_ros_driver.git

# Clone RoboSense SDK with submodules
RUN git clone https://github.com/RoboSense-LiDAR/rslidar_sdk.git && \
    cd rslidar_sdk && \
    git submodule init && \
    git submodule update

# 6. Configure SDK using your CMakeLists logic
# Patch CMakeLists.txt compile flags (enable transform, IMU data and set message type)
RUN cd rslidar_sdk && \
    sed -i 's/option(ENABLE_TRANSFORM "Enable transform functions" OFF)/option(ENABLE_TRANSFORM "Enable transform functions" ON)/g' CMakeLists.txt && \
    sed -i 's/option(ENABLE_IMU_DATA_PARSE           "Enable imu data parse" OFF)/option(ENABLE_IMU_DATA_PARSE "Enable imu data parse" ON)/g' CMakeLists.txt && \
    sed -i 's/set(POINT_TYPE XYZI)/set(POINT_TYPE XYZIRT)/g' CMakeLists.txt

# 7. Get the updated config file inside '/config' (lidar type, min and max range) 
RUN wget -O /catkin_ws/src/rslidar_sdk/config/config.yaml \
    https://raw.githubusercontent.com/Ilyes-Origamist/robosense_fast_lio/RS-Airy/config/rslidar_sdk_cfg.yaml
# COPY catkin_ws/src/rslidar_sdk/config/config.yaml /catkin_ws/src/robosense_fast_lio/config/rslidar_sdk_cfg.yaml

# OR MOUNT THE WHOLE DIRECTORY IN THE DOCKER RUN COMMAND 
# (THIS WILL OVERWRITE THE DIRECTORY BUT NEED TO COMPILE INSIDE THE DOCKER CONTAINER):
# docker run -v ~/catkin_ws/src/rslidar_sdk:/catkin_ws/src/rslidar_sdk/ rs_fast_lio

# 8. Build Workspace
WORKDIR /catkin_ws
RUN source /opt/ros/noetic/setup.bash && \
    catkin_make -DCMAKE_BUILD_TYPE=Release

# 9. Finalize Environment
RUN echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc && \
    echo "source /catkin_ws/devel/setup.bash" >> ~/.bashrc

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]