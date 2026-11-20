# ওয়েব হোম হেডার (Android-এর মতো)
ফাইল দুটো ওয়েব রিপোতে বসাও (git diff দিয়ে বদল দেখা যাবে):
- lib/screens/feed_screen.dart
- lib/screens/home_shell.dart

কী বদলালো
- হেডার: নাম + সার্চ + কালো "+" (নতুন পোস্ট) + বেল (নোটিফিকেশন)
- All / Following / Videos / Premium চিপ (Android-এর একই ফিল্টার)
- নিচের নেভ: Home, Explore, Reels, Chat, Profile (Alerts বেল-এ গেছে)
- ভাসমান "+" বাটন সরানো (হেডারের "+" আছে)
- বড় স্ক্রিনে সাইডবারে Alerts আলাদা আইটেম

বসানোর পর: git add, commit, push, GitHub Actions build।
