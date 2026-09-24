#ifndef RUNNER_SPELL_CHECK_H_
#define RUNNER_SPELL_CHECK_H_

#include <string>
#include <vector>

// A misspelled word: UTF-16 offset and length in the checked text (the
// indexes of a Dart string), and up to five suggestions.
struct SpellingError {
  unsigned long start;
  unsigned long length;
  std::vector<std::wstring> suggestions;
};

// Windows Spell Checking API (Windows 8+) with the Russian, Kazakh and
// English dictionaries that are installed: a word is an error only when none
// of them knows it, so English terms in a Russian letter stay unmarked.
std::vector<SpellingError> CheckSpelling(const std::wstring& text);

#endif  // RUNNER_SPELL_CHECK_H_
