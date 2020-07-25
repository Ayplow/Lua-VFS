// module lua.ast;

// auto isSpace(char c) {
//     switch (c) {
//         case ' ':
//         case '\n':
//         case '\t':
//         case '\r':
//             return true;
//         default:
//             return false;
//     }
// }
// auto escaped(char c) {
//     switch (c) {
//         case '\r': return ['\\', 'r'];
//         case '\n': return ['\\', 'n'];
//         case '"': return ['\\', '"'];
//         case '\'': return ['\\', '\''];
//         default: return [c];
//     }
// }
// auto isLower(char c) {
//     switch(c) {
//         case 'a': .. case 'a': return true;
//         default: return false;
//     }
// }
// auto isUpper(char c) {
//     switch(c) {
//         case 'A': .. case 'Z': return true;
//         default: return false;
//     }
// }
// auto isDigit(char c) {
//     switch(c) {
//         case '0': .. case '9': return true;
//         default: return false;
//     }
// }
// auto isHexDigit(char c) {
//     switch(c) {
//         case '0': .. case '9': return true;
//         case 'A': .. case 'F': return true;
//         case 'a': .. case 'f': return true;
//         default: return false;
//     }
// }
// struct AST {
//     enum BinaryOp {
//         add = "+",
//         sub = "-",
//         mul = "*",
//         div = "/",
//         idiv = "//",
//         mod = "%",
//         pow = "^",
//         concat = "..",

//         band = "&",
//         bor = "|",
//         xor = "~",
//         shl = "<<",
//         shr = ">>",

//         and = "and",
//         or = "or",
//     }
// }
// auto isSymbol(string c) {
//     switch(c) {
//         case AST.BinaryOp.add:
//             return true;
//         default:
//             return false;
//     }
// }