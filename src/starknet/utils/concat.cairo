use array::ArrayTrait;
use array::SpanTrait;
use gas::get_gas;

trait ArrayConcatTrait<T> {
    fn concat(self: Array<T>, arr_2: @Array<T>) -> Array<T>;
}

impl FeltArrayConcatImpl of ArrayConcatTrait::<felt> {
    #[inline(always)]
    fn concat(mut self: Array<felt>, arr_2: @Array<felt>) -> Array<felt> {
        concat_loop(arr_2.span(), ref self);
        self
    }
}

fn concat_loop(mut src: Span<felt>, ref dest: Array<felt>) {
    match get_gas() {
        Option::Some(_) => {},
        Option::None(_) => {
            let mut data = array_new();
            array_append(ref data, 'OOG');
            panic(data);
        },
    }
    match src.pop_front() {
        Option::Some(v) => {
            dest.append(*v);
            concat_loop(src, ref dest);
        },
        Option::None(_) => (),
    }
}
