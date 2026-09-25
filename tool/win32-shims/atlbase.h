#pragma once

// ─────────────────────────────────────────────────────────────────────────────
// Shim mínimo de ATL para compilar los plugins de Flutter en un equipo sin el
// componente "C++ ATL" de Visual Studio Build Tools.
//
// Lo usa el build de Windows vía la flag /I de CMAKE_CXX_FLAGS:
//   - flutter_local_notifications_windows (src/plugin.cpp: #include <atlbase.h>)
//   - flutter_secure_storage_windows      (…_plugin.cpp:   #include <atlstr.h>)
//
// Símbololo requerido por esos dos plugins:
//   - CW2A(ptr [, codePage]) → std::string  (ancho → narrow)
//   - CA2W(ptr [, codePage]) con miembro `.m_psz` (narrow → ancho)
// Si un upgrade del plugin usa más de ATL, ampliar aquí o instalar el
// componente real:  setup.exe modify --add Microsoft.VisualStudio.Component.VC.ATL
// ─────────────────────────────────────────────────────────────────────────────

#include <string>

#include <windows.h>

namespace atl_shim {

// wchar_t* → std::string con el code page indicado (CP_ACP por defecto).
inline std::string WideToNarrow(const wchar_t* src, UINT codePage) {
  if (src == nullptr) {
    return std::string();
  }
  const int needed =
      ::WideCharToMultiByte(codePage, 0, src, -1, nullptr, 0, nullptr, nullptr);
  if (needed <= 0) {
    return std::string();
  }
  std::string out(static_cast<size_t>(needed), '\0');
  ::WideCharToMultiByte(codePage, 0, src, -1, out.data(), needed, nullptr,
                        nullptr);
  out.pop_back();  // quita el terminador nulo
  return out;
}

// char* → std::wstring con el code page indicado (CP_ACP por defecto).
inline std::wstring NarrowToWide(const char* src, UINT codePage) {
  if (src == nullptr) {
    return std::wstring();
  }
  const int needed = ::MultiByteToWideChar(codePage, 0, src, -1, nullptr, 0);
  if (needed <= 0) {
    return std::wstring();
  }
  std::wstring out(static_cast<size_t>(needed), L'\0');
  ::MultiByteToWideChar(codePage, 0, src, -1, out.data(), needed);
  out.pop_back();  // quita el terminador nulo
  return out;
}

}  // namespace atl_shim

// Equivalente funcional de ATL::CW2A: convierte wchar_t* → std::string.
// Se usa como `std::string s = CW2A(ptr, CP_UTF8);` (vía operator const
// char*()) o vía `.m_psz` como en ATL.
class CW2A {
 public:
  CW2A(const wchar_t* src, UINT codePage = CP_ACP)
      : m_buf(atl_shim::WideToNarrow(src, codePage)) {
    Repoint();
  }
  CW2A(const std::wstring& src, UINT codePage = CP_ACP)
      : CW2A(src.c_str(), codePage) {}

  CW2A(const CW2A& other) : m_buf(other.m_buf) { Repoint(); }
  CW2A& operator=(const CW2A& other) {
    m_buf = other.m_buf;
    Repoint();
    return *this;
  }

  operator const char*() const noexcept { return m_psz; }

  // Miembro estilo ATL: buffer con el resultado (narrow).
  char* m_psz = nullptr;

 private:
  void Repoint() {
    m_psz = m_buf.empty() ? const_cast<char*>("") : &m_buf[0];
  }

  std::string m_buf;
};

// Equivalente funcional de ATL::CA2W: convierte char* → wchar_t*.
// Los plugins lo usan como `CA2W target_name(key.c_str());` y leen
// `target_name.m_psz` (debe ser LPWSTR no-const: se asigna a
// `CREDENTIALW.TargetName`, que es LPWSTR).
class CA2W {
 public:
  CA2W(const char* src, UINT codePage = CP_ACP)
      : m_buf(atl_shim::NarrowToWide(src, codePage)) {
    Repoint();
  }
  CA2W(const std::string& src, UINT codePage = CP_ACP)
      : CA2W(src.c_str(), codePage) {}

  CA2W(const CA2W& other) : m_buf(other.m_buf) { Repoint(); }
  CA2W& operator=(const CA2W& other) {
    m_buf = other.m_buf;
    Repoint();
    return *this;
  }

  operator const wchar_t*() const noexcept { return m_psz; }

  // Miembro estilo ATL: buffer con el resultado (ancho).
  wchar_t* m_psz = nullptr;

 private:
  void Repoint() {
    m_psz = m_buf.empty() ? const_cast<wchar_t*>(L"") : &m_buf[0];
  }

  std::wstring m_buf;
};
