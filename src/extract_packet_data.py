#!/usr/bin/env python3
import rosbag
import struct
# from scipy.spatial.transform import Rotation as R
import sys

# bag_path = "/catkin_ws/2026-03-12-11-43-27.bag"

def extract_imu_calibration(bag_path):
    print(f"Opening {bag_path}...")
    
    # The expected DIFOP header sequence
    difop_header = (0xA5, 0xFF, 0x00, 0x5A, 0x11, 0x11, 0x55, 0x55)
    
    with rosbag.Bag(bag_path, 'r') as bag:
        for topic, msg, t in bag.read_messages(topics=['/rslidar_packets']):
            
            # Check if the driver flagged it as DIFOP, or if the header matches
            if msg.is_difop or tuple(msg.data[0:8]) == difop_header:
                print("Found DIFOP Packet!")
                
                # Double check the length just in case
                if len(msg.data) < 1092 + 28:
                    print("Packet too short, skipping...")
                    continue
                
                # Extract the 28 bytes at offset 1092
                calib_bytes = bytearray(msg.data[1092:1092+28])
                
                # Unpack the bytes into 7 little-endian floats ('<7f')
                # Format: q_x, q_y, q_z, q_w, x, y, z
                # DIFOP uses big-endian
                values = struct.unpack('>7f', calib_bytes)
                qx, qy, qz, qw, x, y, z = values
                
                print("\n--- Raw Calibration Values ---")
                print(f"Quaternion (x, y, z, w): {qx:.6f}, {qy:.6f}, {qz:.6f}, {qw:.6f}")
                print(f"Translation (x, y, z):   {x:.6f}, {y:.6f}, {z:.6f}")
                
                # Convert Quaternion to 3x3 Rotation Matrix
                # scipy expects [x, y, z, w]
                # rot = R.from_quat([qx, qy, qz, qw])
                # rot_matrix = rot.as_matrix()
                
                # print("\n--- FAST-LIO YAML Configuration ---")
                # print("mapping:")
                # print(f"  extrinsic_T: [{x:.6f}, {y:.6f}, {z:.6f}]")
                # print("  extrinsic_R: [{:.6f}, {:.6f}, {:.6f},".format(rot_matrix[0][0], rot_matrix[0][1], rot_matrix[0][2]))
                # print("                {:.6f}, {:.6f}, {:.6f},".format(rot_matrix[1][0], rot_matrix[1][1], rot_matrix[1][2]))
                # print("                {:.6f}, {:.6f}, {:.6f}]".format(rot_matrix[2][0], rot_matrix[2][1], rot_matrix[2][2]))
                
                # We only need one DIFOP packet, so we can stop here
                return

    print("Finished reading bag. No valid DIFOP packet found.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 extract_difop.py <path_to_your_rosbag.bag>")
    else:
        extract_imu_calibration(sys.argv[1])