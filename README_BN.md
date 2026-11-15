# Facehub WEB প্রজেক্ট (Android প্রজেক্ট থেকে সম্পূর্ণ আলাদা)

এই ফোল্ডার = **Web**। Android প্রজেক্টে কিছু মেশাবে না।

## স্টেজ ১-এ যা আছে
Login, Home feed (For you / Following), Reels, Profile (নিজের + অন্যের, Follow), Like, Comment।
Chat পরের স্টেজ।

## GitHub-এ তোলা (একবারই)
1. GitHub-এ নতুন **Private** repo খোলো (নাম: facehub-web)।
2. এই ফোল্ডারের সব ফাইল (`.github` ফোল্ডারসহ) repo-র root-এ রাখো। (google-services.json, serviceAccountKey.json, params-local.php কখনো দেবে না)
3. Commit করে push করো (branch: `web` বা `main`)।
4. GitHub → Actions → **Build Web** চালু হবে। শেষ হলে নিচে Artifacts থেকে `web-build` নামাও।
5. `web-build`-এর ভেতরের সব ফাইল সার্ভারে নতুন site root-এ আপলোড করো (যেমন app.sbehf.com)।

Build ফেল করলে লাল লাইনের error টেক্সট আমাকে পাঠাও, ঠিক করে দেব।

## সার্ভারে একটি বাধ্যতামূলক কাজ
`corsfix.zip` → `api/config/main.php` বদলাও (browser-এর preflight ঠিক করে)। না করলে Web-এ সব API কল fail করবে।
এরপর API ডোমেইন বদলালে `lib/config.dart`-এর `apiBase` বদলাও।
