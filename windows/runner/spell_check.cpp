#include "spell_check.h"

#include <windows.h>
#include <objidl.h>
#include <spellcheck.h>
#include <wrl/client.h>

using Microsoft::WRL::ComPtr;

namespace {

// CLSID_SpellCheckerFactory, defined here so no import library is needed.
const CLSID kSpellCheckerFactory = {
    0x7AB36653, 0x1796, 0x484B, {0xBD, 0xFA, 0xE7, 0x4F, 0x1D, 0xB7, 0xC1, 0xDC}};

struct Checker {
  ComPtr<ISpellChecker> checker;
  bool latin;  // English: the one that suggests for Latin words
};

std::vector<Checker> Checkers() {
  std::vector<Checker> checkers;
  ComPtr<ISpellCheckerFactory> factory;
  if (FAILED(::CoCreateInstance(kSpellCheckerFactory, nullptr, CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&factory)))) {
    return checkers;
  }
  for (const wchar_t* language : {L"ru-RU", L"kk-KZ", L"en-US"}) {
    BOOL supported = FALSE;
    if (FAILED(factory->IsSupported(language, &supported)) || !supported) continue;
    ComPtr<ISpellChecker> checker;
    if (SUCCEEDED(factory->CreateSpellChecker(language, &checker))) {
      checkers.push_back({checker, std::wstring(language) == L"en-US"});
    }
  }
  return checkers;
}

bool Knows(ISpellChecker* checker, const std::wstring& word) {
  ComPtr<IEnumSpellingError> errors;
  if (FAILED(checker->Check(word.c_str(), &errors)) || !errors) return false;
  ComPtr<ISpellingError> error;
  return errors->Next(&error) != S_OK;
}

std::vector<std::wstring> Suggest(ISpellChecker* checker, const std::wstring& word) {
  std::vector<std::wstring> out;
  ComPtr<IEnumString> suggestions;
  if (FAILED(checker->Suggest(word.c_str(), &suggestions)) || !suggestions) return out;
  LPOLESTR text = nullptr;
  ULONG fetched = 0;
  while (out.size() < 5 && suggestions->Next(1, &text, &fetched) == S_OK && fetched == 1) {
    out.emplace_back(text);
    ::CoTaskMemFree(text);
  }
  return out;
}

}  // namespace

std::vector<SpellingError> CheckSpelling(const std::wstring& text) {
  std::vector<SpellingError> result;
  auto checkers = Checkers();
  if (checkers.empty() || text.empty()) return result;
  ISpellChecker* primary = checkers.front().checker.Get();
  ComPtr<IEnumSpellingError> errors;
  if (FAILED(primary->Check(text.c_str(), &errors)) || !errors) return result;
  ComPtr<ISpellingError> error;
  while (errors->Next(&error) == S_OK) {
    ULONG start = 0;
    ULONG length = 0;
    CORRECTIVE_ACTION action = CORRECTIVE_ACTION_NONE;
    error->get_StartIndex(&start);
    error->get_Length(&length);
    error->get_CorrectiveAction(&action);
    error.Reset();
    if (length == 0 || action == CORRECTIVE_ACTION_NONE || start + length > text.size()) continue;
    const std::wstring word = text.substr(start, length);
    bool known = false;
    for (size_t i = 1; i < checkers.size() && !known; i++) {
      known = Knows(checkers[i].checker.Get(), word);
    }
    if (known) continue;
    // Suggestions from the dictionary of the word's script.
    ISpellChecker* suggester = primary;
    if (word[0] < 0x80) {
      for (const auto& c : checkers) {
        if (c.latin) suggester = c.checker.Get();
      }
    }
    result.push_back({start, length, Suggest(suggester, word)});
  }
  return result;
}
