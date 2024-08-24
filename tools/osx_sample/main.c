#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>
#include <limits.h>

#include <spawn.h>
#include <sys/wait.h>
#include <mach/mach.h>

typedef char name_t[128];
extern kern_return_t bootstrap_register2(mach_port_t bp, name_t service_name, mach_port_t sp, uint64_t flags);

char **setup_envs(char *path, char **envp) {
	int env_len = 1;
	char **environ = envp;
	while (*environ) {
		env_len++;
		environ++;
	}

	char **envs = calloc(sizeof(char *), env_len + 1);
	int path_buffer_size = PATH_MAX + 1025;
	char *path_buffer = calloc(path_buffer_size, 1);
	snprintf(path_buffer, path_buffer_size, "DYLD_INSERT_LIBRARIES=%s/%s", path, "same.dylib");

	for (int i = 0; i < env_len; i++) {
		envs[i] = envp[i];
	}
	envs[env_len - 1] = path_buffer;
	return envs;
}

void sample_task(mach_port_t task) {
	thread_act_array_t thread_list;
	mach_msg_type_number_t thread_count;
	kern_return_t err = task_threads(task, &thread_list, &thread_count);
	if (err != 0) {
		return;
	}

	printf("Pausing all threads\n");
	for (int i = 0; i < thread_count; i++) {
		thread_act_t thread = thread_list[i];
		thread_suspend(thread);

	}

	printf("Sampling all threads\n");
	for (int i = 0; i < thread_count; i++) {
		thread_act_t thread = thread_list[i];

		x86_thread_state64_t state;
		mach_msg_type_number_t state_count = x86_THREAD_STATE64_COUNT;
		err = thread_get_state(thread, x86_THREAD_STATE64, (thread_state_t)&state, &state_count);
		if (err != 0) {
			return;
		}

		printf("RIP: 0x%08llx\n", state.__rip);
		printf("RSP: 0x%08llx\n", state.__rsp);
		printf("RAX: 0x%08llx\n", state.__rax);
		printf("RBX: 0x%08llx\n", state.__rbx);
		printf("RCX: 0x%08llx\n", state.__rcx);

		thread_resume(thread);
	}
}

int main(int argc, char **argv, char **envp) {
	if (argc < 2) {
		printf("Expected same <program>\n");
		return 1;
	}

	char my_path[PATH_MAX+1];
	if (getcwd(my_path, sizeof(my_path)) == NULL) {
		printf("Failed to get path of same\n");
		return 1;
	}
	char *program_name = argv[1];
	char **my_argv = argv + 1;

	char **envs = setup_envs(my_path, envp);

	mach_port_t recv_port;
	mach_port_t my_task = mach_task_self();
	kern_return_t err = mach_port_allocate(my_task, MACH_PORT_RIGHT_RECEIVE, &recv_port);
	if (err != 0) {
		printf("oops?\n");
		exit(1);
	}

	mach_port_t bootstrap_port;
	err = task_get_special_port(my_task, TASK_BOOTSTRAP_PORT, &bootstrap_port);
	if (err != 0) {
		printf("oops 2?\n");
		exit(1);
	}

	mach_port_t right;
	mach_port_t acquired_right;
	err = mach_port_extract_right(my_task, recv_port, MACH_MSG_TYPE_MAKE_SEND, &right, &acquired_right);
	if (err != 0) {
		printf("oops 3?\n");
		exit(1);
	}

	err = bootstrap_register2(bootstrap_port, "SAME_BOOTSTRAP", right, 0);
	if (err != 0) {
		printf("oops 4?\n");
		exit(1);
	}

	pid_t child_pid;
	int status = posix_spawn(&child_pid, program_name, NULL, NULL, my_argv, envs);
	if (status == 0) {
		printf("Child pid: %i\n", child_pid);
		struct {
			mach_msg_header_t             header;
			mach_msg_body_t                 body;
			mach_msg_port_descriptor_t task_port;
			mach_msg_trailer_t           trailer;
		} recv_msg;

		err = mach_msg(&recv_msg.header, MACH_RCV_MSG, 0, sizeof(recv_msg), recv_port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
		if (err != 0) {
			printf("oops 5\n");
			exit(1);
		}
		mach_port_t child_task = recv_msg.task_port.name;

		err = mach_msg(&recv_msg.header, MACH_RCV_MSG, 0, sizeof(recv_msg), recv_port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
		if (err != 0) {
			printf("oops 6\n");
			exit(1);
		}
		mach_port_t child_port = recv_msg.task_port.name;

		sample_task(child_task);

		struct {
			mach_msg_header_t             header;
			mach_msg_body_t                 body;
			mach_msg_port_descriptor_t task_port;
		} send_msg;

		send_msg.header.msgh_remote_port = child_port;
		send_msg.header.msgh_local_port = MACH_PORT_NULL;
		send_msg.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0) | MACH_MSGH_BITS_COMPLEX;
		send_msg.header.msgh_size = sizeof(send_msg);

		send_msg.body.msgh_descriptor_count = 1;
		send_msg.task_port.name = my_task;
		send_msg.task_port.disposition = MACH_MSG_TYPE_COPY_SEND;
		send_msg.task_port.type = MACH_MSG_PORT_DESCRIPTOR;

		err = mach_msg_send(&send_msg.header);
		if (err != 0) {
			printf("Oops 6\n");
			exit(1);
		}

		do {
			if (waitpid(child_pid, &status, 0) != -1) {
				printf("Child status: %d\n", WEXITSTATUS(status));
			} else {
				perror("waitpid");
				return 1;
			}
		} while (!WIFEXITED(status) && !WIFSIGNALED(status));
	} else {
		printf("posix_spawn: %s\n", strerror(status));
	}

	return 0;
}
