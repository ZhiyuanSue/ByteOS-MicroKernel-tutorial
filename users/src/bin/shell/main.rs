#![no_std]
#![no_main]
#![feature(exclusive_range_pattern)]

use alloc::{string::String, vec::Vec};
use syscall_consts::{Message, MessageContent, IPC_ANY};
use users::syscall::{
    fs_read_dir, get_block_capacity, ipc_call, ipc_recv, serial_read, serial_write, service_lookup,
    sys_time, sys_uptime, task_self, exit, shutdown
};

#[macro_use]
extern crate users;
extern crate alloc;

// 字符集合
const LF: u8 = b'\n';
const CR: u8 = b'\r';
const DL: u8 = b'\x7f';
const BS: u8 = b'\x08';
const SPACE: u8 = b' ';

#[no_mangle]
fn main() {
    let mut message = Message::blank();
    println!("Hello shell!");
    println!("Shell server id: {}", task_self());
    // 输出系统时间
    println!("UPTIME: {}", sys_uptime());

    // 等待 100ms 其他任务启动完毕，否则 log 可能会混乱
    sys_time(100);
    // ipc_recv(IPC_ANY, &mut message);

	// Ping-Pong 命令，测试 IPC 和服务
	{
		println!("start test ping pong!");
		if let Some(task_pong_id) = service_lookup("pong") {
			message.content = MessageContent::PingMsg(321);
			println!("Send ping message {} to vm server", 321);
			ipc_call(task_pong_id, &mut message);
			println!("Ping message reply {:?}", message.content);
		}
		println!("end test ping pong!");
	}
	// 输出帮助信息
	{
		println!("commands available are below:");
		["help", "ping"].iter().for_each(|x| {
			println!("{:>10}", x);
		});
	}
	shutdown();
}
