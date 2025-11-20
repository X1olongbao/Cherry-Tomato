# Supabase OTP Setup Guide

Your app now uses Supabase's built-in OTP (One-Time Password) functionality instead of EmailJS. No Edge Functions are needed!

## How It Works

### Signup Flow:
1. User enters email, username, and password
2. App calls `signInWithOtp()` with `shouldCreateUser: true`
3. Supabase sends OTP code to user's email
4. User enters OTP code
5. App verifies OTP with `verifyOTP()`
6. User is automatically signed in
7. App sets password and creates profile

### Forgot Password Flow:
1. User enters email
2. App calls `signInWithOtp()` with `shouldCreateUser: false`
3. Supabase sends OTP code to user's email
4. User enters OTP code
5. App verifies OTP with `verifyOTP()`
6. User is signed in temporarily
7. User can then reset their password

## Supabase Dashboard Configuration

### 1. Enable Email Auth
- Go to **Authentication** → **Providers** in your Supabase dashboard
- Ensure **Email** provider is enabled
- Configure email settings if needed

### 2. Configure Email Templates
- Go to **Authentication** → **Email Templates**
- Customize the **Magic Link** template (this is used for OTP)

#### Recommended Email Template:

**Subject:**
```
Verify Your Email - Cherry Tomato
```

**Body (HTML):**
```html
<h2>Your Verification Code</h2>
<p>Use this code to verify your email:</p>
<h1 style="font-size: 32px; letter-spacing: 8px; color: #E53935;">{{ .Token }}</h1>
<p>This code will expire in 15 minutes.</p>
<p>If you didn't request this, please ignore this email.</p>
```

**Note:** Supabase uses `{{ .Token }}` for the OTP code. The token is typically a 6-digit code.

### 3. Email Settings
- Go to **Authentication** → **Settings**
- Configure **Site URL** (your app's URL)
- Configure **Redirect URLs** if needed
- Set up **SMTP** settings if you want to use a custom email service (optional)

### 4. Rate Limiting (Optional)
- Go to **Authentication** → **Settings**
- Configure rate limits for OTP requests to prevent abuse

## Testing

1. **Test Signup:**
   - Enter email, username, and password
   - Check email for OTP code
   - Enter code to verify
   - User should be signed in and redirected to homepage

2. **Test Forgot Password:**
   - Enter email on forgot password page
   - Check email for OTP code
   - Enter code to verify
   - User should be able to set new password

## Troubleshooting

### OTP Not Received
- Check spam folder
- Verify email is correct
- Check Supabase logs in dashboard
- Ensure email provider is enabled
- Verify SMTP settings if using custom email

### Invalid OTP Error
- OTP codes expire after 15 minutes
- Each OTP can only be used once
- Request a new OTP if expired

### User Creation Issues
- Ensure `shouldCreateUser: true` for signup
- Check database permissions for `profiles` table
- Verify RLS (Row Level Security) policies

## Code Files Updated

- ✅ `lib/userloginforgot/sign_up_page.dart` - Uses `signInWithOtp()`
- ✅ `lib/userloginforgot/forgot_pass_page.dart` - Uses `signInWithOtp()`
- ✅ `lib/userloginforgot/email_otp_verification_page.dart` - Uses `verifyOTP()`
- ✅ `lib/userloginforgot/set_new_pass.dart` - Uses session to update password

## Benefits of Supabase OTP

- ✅ No Edge Functions needed
- ✅ Built-in email delivery
- ✅ Automatic rate limiting
- ✅ Secure token generation
- ✅ Easy to configure
- ✅ Works out of the box

## Next Steps

1. Configure email templates in Supabase dashboard
2. Test the signup flow
3. Test the forgot password flow
4. Customize email templates to match your brand

That's it! Your OTP system is now fully integrated with Supabase. 🎉

