# Robo 3T Apple Silicon (ARM64) & MongoDB 7.0/8.x Upgrade Summary

This document summarizes the complete requirements, development history, debugging steps, and technical changes implemented during the native **Apple Silicon (ARM64)** port and **MongoDB 7.0 & 8.x** upgrade of Robo 3T (Robomongo).

---

## 📋 User Requests & Core Objectives
1. **Apple Silicon Port**: Support native compilation and execution on macOS ARM64 (M1/M2/M3 chips) without Rosetta 2.
2. **MongoDB 7 Upgrade**: Support connection and operations on MongoDB version 7.0 (and 8.x).
3. **Resolve Write Failures**: Fix document insertion/editing errors due to the removal of legacy commands.
4. **Resolve Pagination/Next Page Failures**: Fix query errors when navigating pages.
5. **Custom Branding**: Rename the app to `"Robo 3T 1.4 (iaunn edition)"` in window titles, about dialogs, and welcome page.
6. **Local Welcome Page**: Convert the Welcome tab to load offline local content instead of remote Studio 3T files.
7. **Git Commit & Push**: Commit logical changes to individual branches and push to personal forks (`iaunn/robomongo` and `iaunn/robomongo-shell`).

---

## 🛠️ Technical Challenges & Solutions

### 1. Database Shell (`robomongo-shell`)
* **Challenge**: SpiderMonkey JIT & WebAssembly Exception Handlers on ARM64 macOS.
  * *Solution*: Created macOS aarch64 build profiles by mirroring unified JIT configs. Patched `WasmSignalHandlers.cpp` with thread state register mappings (using `__pc`, `__sp`, `__fp`, `__lr` registers for `__aarch64__` inside Mach exception handlers).
* **Challenge**: Build failures on modern SCons & Python 3.10+.
  * *Solution*: Replaced the deprecated `imp` module with `importlib.util` dynamic imports. Updated keyword-argument validators in Scons files.
* **Challenge**: MongoDB 7.0 `getlasterror` Command Removal.
  * *Solution*: MongoDB 7.0 removed `getlasterror` completely, causing inserts to fail. We changed the write methods in `dbclient_base.cpp` (`insert`, `update`, `remove`) to execute synchronously via standard `runCommand` and parse the response directly for write errors.
* **Challenge**: MongoDB 7.0 `ntoreturn` Query Parameter Removal.
  * *Solution*: MongoDB 7.0 rejects find commands containing the deprecated `ntoreturn` field. We patched `dbclient_cursor.cpp` to globally convert `ntoreturn` to `limit`, restoring full pagination support.

### 2. Qt Client App (`robomongo`)
* **Challenge**: OpenSSL 3.x Linker & Header Resolution.
  * *Solution*: Removed the custom `FindOpenSSL.cmake` and allowed standard CMake module resolution to locate Brew's OpenSSL 3. Linked the `libssh2` submodule dynamically against imported targets.
* **Challenge**: Compiler & Linker incompatibilities under C++17.
  * *Solution*: Added compile flags `-D_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION` globally on Apple. Removed the deprecated `-noall_load` linker option.
* **Challenge**: WebEngine Missing on ARM64 macOS (Qt 5.15).
  * *Solution*: Auto-set `DISABLE_WEBENGINE=ON` on ARM64 macOS and adjusted dynamic packaging rules to exclude missing frameworks.

### 3. Personal Branding & Local Welcome Page
* **Welcome Page Customization**:
  * Disabled remote network downloads in `WelcomeTab.cpp` to prevent analytics calls and external loading.
  * Hardcoded a clean local HTML welcome message branding the application as **`Robo 3T 1.4 (iaunn edition)`** with support specs for MongoDB 7/8.
* **UI Titles**:
  * Updated CMake compile definitions and About Dialog templates to include `(iaunn edition)`.

### 4. Security, Privacy & Stability Hardening
* **Zero Telemetry & Anti-Tracking**:
  * Disabled automatic background update checks and telemetry transmissions to `https://updates.3t.io/check.php` in `MainWindow.cpp`.
  * Stopped scanning local directories for legacy Studio 3T / Robo 3T `anonymousID` tracking identifiers in `SettingsManager.cpp`.
* **Local Credential File Hardening**:
  * Enforced strict owner-only permissions (`0600` on files, `0700` on directories) for `~/.3T/robo-3t/robo3t.key` and `robo3t.json` in `RoboCrypt.cpp` and `SettingsManager.cpp`.
* **JavaScript Injection & Memory Credential Protection**:
  * Added proper escaping for single quotes, backslashes, and control characters when constructing `connect(...)` and `shellHelper.use(...)` calls in `ScriptEngine.cpp`, and used `BSONObj::jsonString()` when removing functions from `db.system.js` in `MongoWorker.cpp`.
  * Cleared plaintext credentials from `mongo::shell_utils::dbConnect` immediately after initializing the SpiderMonkey scope.
* **Thread-Safety & Memory Safety**:
  * Added global mutex synchronization in `ScriptEngine.cpp` and `MongoWorker.cpp` to prevent cross-thread data races on shared SpiderMonkey output buffers (`__objects`, `__logs`, `__type`) and global SSL parameters (`mongo::sslGlobalParams`).
  * Fixed a null pointer dereference bug in `MongoWorker::timerEvent` when invalidating the autocompletion cache.
  * Fixed socket and `addrinfo` resource leaks on connection failures in `src/robomongo/ssh/ssh.c`.
  * In `robomongo-shell`, fixed a heap buffer overflow (`std::max` -> `std::min`) in `SSLConnectionApple::read_func` and disabled legacy TLS 1.0/1.1 protocols by default (`ssl_manager_apple.cpp`).

---

## 💾 Code Repositories & Git History

### 1. `robomongo-shell` (Branch: `roboshell-v4.2`)
* **Fork**: `git@github.com:iaunn/robomongo-shell.git`
* **Commits**:
  1. `2ecafcf899`: *Build: Fix SCons scripts for Python 3.10+ and macOS ARM64 compilation*
  2. `adf685d79e`: *Third-Party: Add macOS ARM64 SpiderMonkey JIT/exception handler support and Boost C++17 fixes*
  3. `b5377728db`: *Client: Implement MongoDB 7.0 compatibility by running writes synchronously and converting ntoreturn to limit*
  4. `da2f1a37e8`: *Security: Enforce TLS 1.2+, fix Apple SSL buffer overflow, and fix AppleClang 21 s2polyline build*

### 2. `robomongo` (Branch: `feature/apple-silicon-mongodb-upgrade`)
* **Fork**: `git@github.com:iaunn/robomongo.git`
* **Commits**:
  1. `afe15692`: *Build: Resolve C++17 compatibility, OpenSSL 3 integration, and update GoogleTest CMake requirements*
  2. `bbc66d77`: *Packaging: Remove deprecated macOS linker flags and dynamically package OpenSSL 3 / skip WebEngine*
  3. `a7cb69c5`: *Packaging: Update macOS database shell objects list for ARM64 and MongoDB 7.0*
  4. `9c031074`: *Branding: Update project name and version title to include '(iaunn edition)'*
  5. `18befbf9`: *Branding: Implement custom welcome tab and window title for iaunn edition*
  6. `3e575857`: *Build: Integrate automated macdeployqt deployment during CPack packaging*
  7. `48be556e`: *Build: Exclude manual copies on macOS to let macdeployqt deploy and rewrite nested framework dependencies recursively*

---

## 🚀 Building & Installation Instructions

### 1. Rebuild the Database Shell
```bash
cd /Users/iaunn/workspace/iaunn/robomongo-shell
bin/build
```

### 2. Rebuild the Client App
```bash
cd /Users/iaunn/workspace/iaunn/robomongo
export ROBOMONGO_CMAKE_PREFIX_PATH="/opt/homebrew/opt/qt@5;/Users/iaunn/workspace/iaunn/robomongo-shell;/opt/homebrew/opt/openssl@3"
bin/configure release
bin/build
bin/install
```

### 3. Install App to System Applications
```bash
cp -R "/Users/iaunn/workspace/iaunn/robomongo/build/release/install/Robo 3T.app" /Applications/
```
