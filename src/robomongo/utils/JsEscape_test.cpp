#include "gtest/gtest.h"
#include "robomongo/utils/JsEscape.h"

using Robomongo::escapeJsSingleQuotedString;

TEST(JsEscapeTests, PlainStringUnchanged)
{
    EXPECT_EQ("localhost:27017/test", escapeJsSingleQuotedString("localhost:27017/test"));
}

TEST(JsEscapeTests, QuotesAndBackslashEscaped)
{
    EXPECT_EQ("a\\'b\\\\c\\\"d", escapeJsSingleQuotedString("a'b\\c\"d"));
}

TEST(JsEscapeTests, InjectionAttemptStaysInsideLiteral)
{
    EXPECT_EQ("x\\'); evil(); (\\'", escapeJsSingleQuotedString("x'); evil(); ('"));
}

TEST(JsEscapeTests, ControlCharactersEscaped)
{
    EXPECT_EQ("a\\nb\\rc\\td\\x00e", escapeJsSingleQuotedString(std::string("a\nb\rc\td\0e", 9)));
}

TEST(JsEscapeTests, LineSeparatorsEscaped)
{
    EXPECT_EQ("a\\u2028b\\u2029c", escapeJsSingleQuotedString("a\xE2\x80\xA8" "b\xE2\x80\xA9" "c"));
}

TEST(JsEscapeTests, OtherUtf8Preserved)
{
    EXPECT_EQ("\xE0\xB8\x81\xE0\xB8\xB2", escapeJsSingleQuotedString("\xE0\xB8\x81\xE0\xB8\xB2"));
}
