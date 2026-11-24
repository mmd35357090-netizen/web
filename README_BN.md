# ওয়েব ক্যাচ-আপ (স্টেজ ২৮-এর পরের সব ওয়েব আপডেট একসাথে)

এতে web_stage28b, web_stage29, web_header, web_logo, web_fix2, web_video_fix —
এই ছয়টার প্রতিটা ফাইলের **সর্বশেষ সংস্করণ** আছে। আলাদা ক্রমে বসাতে হবে না।
কিছু আগে বসানো থাকলেও ক্ষতি নেই (ফলাফল একই)।

## বসাও (ওয়েব রিপোতে, একই পথে, সব ফাইল ওভাররাইট)
- lib/endpoints.dart
- lib/post_video.dart (নতুন)
- lib/video_frame.dart
- lib/screens/create_post_screen.dart
- lib/screens/feed_screen.dart
- lib/screens/home_shell.dart
- lib/screens/login_screen.dart
- lib/screens/post_card.dart
- lib/screens/profile_screen.dart
- web/index.html
- web/favicon.png
- web/icons/ (৫টা আইকন)

কোনো pubspec বদল লাগে না।

## তারপর
git diff দেখো → push → GitHub Actions build → ব্রাউজারে Ctrl+Shift+R বা Incognito।
Build ফেল করলে লাল error লাইন পাঠাও।

## কী পাবে
Android-এর মতো হেডার ও All/Following/Videos/Premium চিপ, লোগো/আইকন, প্রোফাইল একসাথে স্ক্রল,
ভিডিওতে ট্যাপে প্লে/পজ + সাউন্ড বাটন, ফিডে সব পোস্ট (এডমিনের পোস্টসহ), ব্রাউজার বারের রং।
