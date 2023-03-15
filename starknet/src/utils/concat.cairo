use array::ArrayTrait;
use array::SpanTrait;
use gas::get_gas;

trait ArrayTConcatTrait<T> {
    fn concat(self: Array<T>, arr_2: @Array<T>) -> Array<T>;
}

impl ArrayTConcatImpl<T, impl TCopy: Copy::<T>, impl TDrop: Drop::<T>> of ArrayTConcatTrait::<T> {
    fn concat(mut self: Array<T>, arr_2: @Array<T>) -> Array<T> {
        concat_loop::<T, TCopy>(ref self, arr_2.span());
        self
    }
}

fn concat_loop<T, impl TCopy: Copy::<T>, impl TDrop: Drop::<T>>(ref arr_1: Array<T>, mut arr_2: Span<T>) {
    match get_gas() {
        Option::Some(_) => {},
        Option::None(_) => {
            let mut data = array_new();
            array_append(ref data, 'OOG');
            panic(data);
        },
    }
    match arr_2.pop_front() {
        Option::Some(v) => {
            arr_1.append(*v);
            concat_loop::<T, TCopy>(ref arr_1, arr_2);
        },
        Option::None(_) => (),
    }
}
