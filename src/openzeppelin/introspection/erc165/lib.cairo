mod tests;

trait IERC165 {
  fn supports_interface(interface_id: felt) -> bool;
  fn register_interface(interface_id: felt);
}
