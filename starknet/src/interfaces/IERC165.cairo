#[abi]
trait IERC165 {
  fn supports_interface(interface_id: u32) -> bool;
}
