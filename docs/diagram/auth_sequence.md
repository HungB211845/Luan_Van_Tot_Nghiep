```mermaid
sequenceDiagram
    actor User
    participant UI as "UI (Screens)"
    participant AP as "AuthProvider"
    participant AS as "AuthService"
    participant BS as "BiometricService"
    participant SSS as "SecureStorageService"
    participant SS as "SessionService"
    participant StoreS as "StoreService"
    participant DB as "Supabase (DB/Auth/RPC)"

    %% === INITIALIZATION / SPLASH SCREEN ===
    alt App Initialization (SplashScreen)
        User->>+UI: Mở ứng dụng (SplashScreen)
        UI->>+SSS: hasStoreCode()
        SSS-->>-UI: Trả về true/false
        alt If no store code
            UI->>User: Chuyển đến StoreCodeScreen
        else If store code exists
            UI->>+DB: Kiểm tra currentSession
            DB-->>-UI: Trả về session
            alt If no valid session
                UI->>+BS: isAvailable()
                BS-->>-UI: Trả về true/false
                alt If biometric available & credentials stored
                    UI->>User: Chuyển đến BiometricLoginScreen
                else If no biometric or no credentials
                    UI->>User: Chuyển đến LoginScreen
                end
            else If valid session
                UI->>User: Chuyển đến HomeScreen
            end
        end
    end

    %% === LOGIN WITH EMAIL/PASSWORD & STORE CODE ===
    alt Login (Email/Password & Store Code)
        User->>+UI: Nhập email, mật khẩu, mã cửa hàng (LoginScreen)
        UI->>+AP: signInWithStore(email, password, storeCode)
        AP->>+AS: signInWithEmailAndStore(email, password, storeCode)
        AS->>+DB: RPC validate_store_for_login(storeCode)
        Note over DB: Xác thực mã cửa hàng và trả về thông tin cửa hàng
        DB-->>-AS: Trả về store_data
        AS->>+DB: _supabase.auth.signInWithPassword(email, password)
        DB-->>-AS: Trả về user session
        AS->>+DB: SELECT user_profiles WHERE id = user.id AND store_id = store.id
        Note over DB: Xác minh user thuộc về cửa hàng và đang active
        DB-->>-AS: Trả về userProfile
        AS->>+DB: _createOrUpdateSession(user)
        Note over DB: Cập nhật bảng user_sessions
        DB-->>-AS: Xác nhận
        AS->>+DB: _updateUserMetadata(user.id, store.id)
        Note over DB: Cập nhật store_id vào user metadata cho RLS
        DB-->>-AS: Xác nhận
        AS->>+SSS: storeLastStoreCode(storeCode), storeLastStoreId(store.id), storeRefreshToken(token)
        Note over SSS: Lưu thông tin cửa hàng và refresh token cho biometric
        SSS-->>-AS: Xác nhận
        AS-->>-AP: Trả về AuthResult.success
        AP->>AP: Cập nhật AuthState (authenticated, userProfile, store)
        AP-->>-UI: notifyListeners()
        UI->>User: Chuyển đến HomeScreen
    end

    %% === LOGIN WITH BIOMETRIC ===
    alt Login (Biometric)
        User->>+UI: Nhấn nút "Xác thực và đăng nhập" (BiometricLoginScreen)
        UI->>+AP: signInWithBiometric()
        AP->>+AS: signInWithBiometric()
        AS->>+BS: authenticate(reason)
        Note over BS: Yêu cầu xác thực sinh trắc học từ thiết bị
        BS-->>-AS: Trả về true/false
        alt If biometric success
            AS->>+SSS: getBiometricCredentials()
            Note over SSS: Lấy email, password, storeCode đã lưu an toàn
            SSS-->>-AS: Trả về credentials
            AS->>+AS: signInWithEmailAndStore(email, password, storeCode)
            Note over AS: Tái sử dụng luồng đăng nhập chính với credentials đã lưu
            AS-->>-AP: Trả về AuthResult.success
            AP->>AP: Cập nhật AuthState
            AP-->>-UI: notifyListeners()
            UI->>User: Chuyển đến HomeScreen
        else If biometric failed
            AS-->>-AP: Trả về AuthResult.failure
            AP-->>-UI: notifyListeners()
            UI->>User: Hiển thị lỗi
        end
    end

    %% === SIGN UP (OWNER & STORE CREATION) ===
    alt Sign Up (Owner/Store Creation)
        User->>+UI: Nhập thông tin đăng ký (SignupStep1/2/3Screen)
        UI->>+AP: signUp(email, password, storeCode, fullName, storeName, phone)
        AP->>+AS: signUpWithEmail(...)
        AS->>+DB: _supabase.auth.signUp(email, password)
        DB-->>-AS: Trả về user
        AS->>+DB: INSERT INTO stores (store_code, store_name, owner_name, ...)
        DB-->>-AS: Trả về store
        AS->>+DB: INSERT INTO user_profiles (id, store_id, full_name, role: OWNER, ...)
        DB-->>-AS: Trả về userProfile
        AS->>+DB: _createOrUpdateSession(user)
        DB-->>-AS: Xác nhận
        AS->>+DB: _updateUserMetadata(user.id, store.id)
        Note over DB: Cập nhật store_id vào user metadata cho RLS
        DB-->>-AS: Xác nhận
        AS-->>-AP: Trả về AuthResult.success
        AP->>AP: Cập nhật AuthState
        AP-->>-UI: notifyListeners()
        UI->>User: Chuyển đến HomeScreen
    end

    %% === LOGOUT ===
    alt Logout
        User->>+UI: Nhấn "Đăng xuất" (AccountScreen)
        UI->>+AP: signOut()
        AP->>+AS: signOut()
        AS->>+DB: _supabase.auth.signOut()
        DB-->>-AS: Xác nhận
        AS->>+SSS: clearSessionDataOnly()
        Note over SSS: Xóa dữ liệu session nhưng giữ lại store code, biometric credentials, remember email
        SSS-->>-AS: Xác nhận
        AS-->>-AP: (AuthChangeEvent.signedOut event kích hoạt _handleAuthChange)
        AP->>AP: Cập nhật AuthState (unauthenticated)
        AP-->>-UI: notifyListeners()
        UI->>User: Chuyển đến LoginScreen
    end

    %% === ENABLE BIOMETRIC ===
    alt Enable Biometric
        User->>+UI: Bật toggle "Đăng nhập bằng Face/Touch ID" (ProfileScreen)
        UI->>UI: Nhập mật khẩu để xác thực
        UI->>+AP: enableBiometricWithPassword(email, password, storeCode)
        AP->>+AS: enableBiometricWithPassword(...)
        AS->>+AS: signInWithEmailAndStore(...)
        Note over AS: Xác minh mật khẩu bằng cách thử đăng nhập lại
        AS-->>-AP: Trả về AuthResult.success
        AP->>+BS: authenticate(reason)
        BS-->>-AP: Trả về true/false
        alt If biometric authentication success
            AP->>+SSS: storeBiometricCredentials(email, password, storeCode)
            SSS-->>-AP: Xác nhận
            AP->>+DB: UPDATE user_profiles SET biometric_enabled = true
            DB-->>-AP: Xác nhận
            AP-->>-UI: notifyListeners()
            UI->>User: Hiển thị thông báo thành công
        else If biometric authentication failed
            AP-->>-UI: notifyListeners()
            UI->>User: Hiển thị lỗi
        end
    end

    %% === DISABLE BIOMETRIC ===
    alt Disable Biometric
        User->>+UI: Tắt toggle "Đăng nhập bằng Face/Touch ID" (ProfileScreen)
        UI->>+AP: disableBiometric()
        AP->>+AS: disableBiometric()
        AS->>+SSS: deleteBiometricCredentials()
        SSS-->>-AS: Xác nhận
        AS->>+DB: UPDATE user_profiles SET biometric_enabled = false
        DB-->>-AS: Xác nhận
        AS-->>-AP: Trả về AuthResult.success
        AP-->>-UI: notifyListeners()
        UI->>User: Hiển thị thông báo thành công
    end
```