use result::ResultTrait;
use array::ArrayTrait;
use debug::PrintTrait;
use option::OptionTrait;

// #[test]
// #[available_gas(20000000)]
// fn test_sandbox() {
//   match starknet::call_contract_syscall(
//     address: starknet::contract_address_const::<0x42>(),
//     entry_point_selector: 0x1,
//     calldata: ArrayTrait::<felt252>::new().span()
//   ) {
//     Result::Ok(res) => {
//       1.print();
//     },
//     Result::Err(mut err) => {
//       0.print();

//       loop {
//         match err.pop_front() {
//           Option::Some(e) => {
//             e.print();
//           },
//           Option::None(()) => {
//             break;
//           },
//         };
//       };
//     }
//   }
// }
