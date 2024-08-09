type c_int = number;
type c_ptrdiff_t = number;
type c_ptr = number;

declare namespace $SHBuiltin {
    function extern_c(includes: any, fn: Function): Function;
}

declare function print(...args: any): void;
