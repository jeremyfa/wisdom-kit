// Without this, a release build on Windows opens a console window behind the
// app. Debug builds keep it, because that is where `println!` goes.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    wisdom_app_lib::run()
}
