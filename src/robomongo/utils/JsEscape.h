#pragma once

#include <cstddef>
#include <string>

namespace Robomongo
{
    /**
     * Escapes a UTF-8 string so that it can be safely embedded between single quotes in a
     * JavaScript string literal (e.g. when building connect('...') / shellHelper.use('...') calls).
     * Handles backslash, quotes, all ASCII control characters and the U+2028/U+2029 line
     * separators (which terminate a JS string literal).
     */
    inline std::string escapeJsSingleQuotedString(std::string const& input)
    {
        static char const* const HEX = "0123456789abcdef";
        std::string out;
        out.reserve(input.size() + 8);
        for (std::size_t i = 0; i < input.size(); ++i) {
            unsigned char const c = static_cast<unsigned char>(input[i]);
            switch (c) {
                case '\\': out += "\\\\"; break;
                case '\'': out += "\\'";  break;
                case '"':  out += "\\\""; break;
                case '\n': out += "\\n";  break;
                case '\r': out += "\\r";  break;
                case '\t': out += "\\t";  break;
                default:
                    if (c < 0x20 || c == 0x7f) {
                        out += "\\x";
                        out += HEX[c >> 4];
                        out += HEX[c & 0xf];
                    }
                    else if (c == 0xE2 && i + 2 < input.size() &&
                             static_cast<unsigned char>(input[i + 1]) == 0x80 &&
                             (static_cast<unsigned char>(input[i + 2]) == 0xA8 ||
                              static_cast<unsigned char>(input[i + 2]) == 0xA9)) {
                        out += (static_cast<unsigned char>(input[i + 2]) == 0xA8) ? "\\u2028" : "\\u2029";
                        i += 2;
                    }
                    else {
                        out += static_cast<char>(c);
                    }
                    break;
            }
        }
        return out;
    }
}
