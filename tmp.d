import std.traits : isIterable, isAutodecodableString, Fields, FieldNameTuple, isNumeric, isStaticArray, isDynamicArray;
import std.algorithm : map;
import std.range : zip, iota;
import std.array : join;
import std.conv : to;
import std.stdio;
// template toJSON(string indent = " ", S) if (isNumeric!S) {
//     alias toJSON = to!string;
// }
// template toJSON(string indent = " ", S) if (is(S: bool)) {
//     alias toJSON = to!string;
// }
// template toJSON(T[U] arr) {
//     auto toJSON(S)(S s) {
//         return "null";
//     }
// }
import std.format : format;
// auto toJSON2(S)(S s) {
//     static if (isAutodecodableString!S) return '"' ~ s ~ '"';
//     else static if (isNumeric!S || is(S: bool)) return s.to!string;
//     else static if (isArray!S) return '[' ~ s.idup.map!toJSON2.join(',') ~ ']';
//     else return '{' ~ mixin([FieldNameTuple!S]
//                         .map!(member => "`\"" ~ member ~ "\":`~s." ~ member ~ ".toJSON2")
//                         .join("~','~")) ~ '}';
// }
// template toJSONChunks(S) {
//     static if (isAutodecodableString!S) immutable toJSONChunks = 3;
//     else static if (isNumeric!S || is(S: bool)) immutable toJSONChunks = 1;
//     else static if (isStaticArray!S) immutable toJSONChunks = 2 + 2 * S.length;
//     else static if (isDynamicArray!S) immutable toJSONChunks = 2;
//     else immutable toJSONChunks = 2 + {
//         buf ~= '{';
//         mixin([FieldNameTuple!S]
//                 .map!(member => format(q{
//                     buf ~= `"%s":`;
//                     s.%s.toJSON(buf);
//                 }, member, member))
//                 .join(""));
//         buf ~= '}';
//     }  
//     return buf;

// }
import std.range : ElementType, isInputRange;
auto toJSON(alias sink, S)(S s) {
    static if (isAutodecodableString!S) {
        sink('"');
        sink(s);
        sink('"');
    } else static if (isNumeric!S || is(S: bool)) sink(s.to!string);
      else static if (isInputRange!S) {

    } else static if (isIterable!S) {
        sink('[');
        void delegate(ElementType!S)* handler;
        handler = (el) {
            el.toJSON!sink;
            *handler = (el) {
                sink(',');
                el.toJSON!sink;
            };
        };
        s.opApply(&handler);
        // foreach (el; s) {
        //     sink(',');
        //     el.toJSON!sink;
        // }
        sink(']');
    } else {
        sink('{');
        mixin([FieldNameTuple!S]
                .map!(member => format(q{
                    sink(`"%s":`);
                    s.%s.toJSON!sink;
                }, member, member))
                .join(""));
        sink('}');
    }
}
// template len(S) {
//     static if (isStaticArray!S) immutable len = 2 + 2 * S.length;
//     else immutable len = 2;
// }
// import std.datetime.stopwatch : benchmark;
void main() {
    // import std.stdio;
    // // A[] data = [{ 2, "Nein", { true } }, { 5, "foo", { false }}];
    struct Person {
        int age;
        string[2] name;
    }
    Person[] people = [{ 12, ["Rob", "Smiles"] }, { 78, ["Nigel", "Mayes"] }];
    people.toJSON!write;
    // string[] foo;
    // writeln(len!(typeof(foo)));
    // writeln(benchmark!({
    //     people.toJSON.to!string;
    // }, {
    //     people.toJSON2;
    // })(100_000));
    // writeln(toJSON!(["foo": 12])(""));
    // string[2] foo = ["a", "b"];
    // import std.uni : asUpperCase;
    // auto n = "what";
    // writeln(foo.idup.map!asUpperCase);
    // writeln(foo.map!capitalize);
}