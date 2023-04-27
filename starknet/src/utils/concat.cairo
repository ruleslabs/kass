use array::ArrayTrait;
use array::SpanTrait;

trait ArrayTConcatTrait<T> {
    fn concat(ref self: Array::<T>, ref arr: Array::<T>);
}

impl ArrayTConcatImpl<T, impl TDrop: Drop::<T>> of ArrayTConcatTrait::<T> {
    fn concat(ref self: Array::<T>, ref arr: Array::<T>) {
        match gas::withdraw_gas() {
            Option::Some(_) => {},
            Option::None(_) => {
                let mut data = array::array_new();
                array::array_append(ref data, 'OOG');
                panic(data);
            },
        }
        match arr.pop_front() {
            Option::Some(v) => {
                self.append(v);
                self.concat(ref arr);
            },
            Option::None(_) => (),
        }
    }
}
