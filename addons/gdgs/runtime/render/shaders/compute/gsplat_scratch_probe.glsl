#[compute]
#version 460

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(std430, set = 0, binding = 0) restrict buffer ScratchProbeBuffer {
	uint scratch_probe[];
};

void main() {
	scratch_probe[0] = 0x47534744u; // 'GDGS'
	scratch_probe[1] = gl_NumWorkGroups.x;
	scratch_probe[2] = gl_WorkGroupSize.x;
	scratch_probe[3] = 0x5A5AA5A5u;
}
