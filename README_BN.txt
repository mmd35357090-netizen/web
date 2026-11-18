লক্ষ্য: ব্যবহারকারী শুধু connecttofriends.com দেখবে। c2f.connecttofriends.com হলো লুকানো ব্যাকএন্ড (API + অ্যাডমিন + চ্যাট + কল)।

ধাপ ১ (c2f সাইট): aaPanel -> Website: যে সাইটে এখন API/অ্যাডমিন (Yii) আছে, তাতে c2f.connecttofriends.com ডোমেইন যোগ করুন (Domain alias), DNS A রেকর্ড 185.197.250.191।
        SSL -> Let's Encrypt এ c2f.connecttofriends.com সহ সার্টিফিকেট নিন। পুরোনো facehub.sbehf.com আপাতত চালু রাখুন (এখনকার Android অ্যাপ ওটা ব্যবহার করে)।
ধাপ ২ (params-local.php): 'siteUrl' => 'https://c2f.connecttofriends.com' (ছবি/ভিডিওর ঠিকানা এটা দিয়ে তৈরি হয়; ওয়েব অ্যাপ এগুলো connecttofriends.com করে দেখায়)।
        'webAppUrl' => 'https://connecttofriends.com' (শেয়ার লিংকের জন্য)।
        ইমেইল/পাসওয়ার্ড-রিসেট লিংক যেন c2f না দেখায় - ওসব লিংকে connecttofriends.com ব্যবহার করুন।
ধাপ ৩ (চ্যাট ও কল সার্ভার): সার্টিফিকেট c2f এর দিন (aaPanel এর cert ফোল্ডারের পূর্ণ পথ)।
        call/ecosystem.config.js: VERIFY_URL = https://c2f.connecttofriends.com/api/web/v1/rtc/config ; SSL_CERT/SSL_KEY = c2f এর পথ।
        ownCall: signalingUrl = https://c2f.connecttofriends.com:4100 , turnHost = c2f.connecttofriends.com ; coturn realm = c2f.connecttofriends.com
        চ্যাট সার্ভারের webOrigins এ https://connecttofriends.com যোগ করুন।
ধাপ ৪ (ওয়েব ফাইল): web_stage28 এর lib ফাইল বসান। lib/config.dart এ:
        static const String apiBase = '/api/web/v1/';
        static const socketUrl = '/';
ধাপ ৫ (connecttofriends.com এর Apache): apache_proxy_connecttofriends.conf এর লাইন বসান (এখন প্রক্সি c2f এ যায়)।
ধাপ ৬ (সাইটের রুট): web-build ফাইল connecttofriends.com এর document root এ দিন (আগের ডাউনলোড-পেজ সরবে; Privacy Policy/Terms/অ্যাকাউন্ট-মুছুন পেজ থাকলে আগে অন্য পথে সরান)।
ধাপ ৭ (Google): Authorized JavaScript origins এ https://connecttofriends.com যোগ করুন।
ধাপ ৮ (অ্যাডমিন সুরক্ষা): c2f এর /backend শুধু আপনার আইপি থেকে খোলার নিয়ম দিন (Require ip) + 2FA/শক্ত পাসওয়ার্ড।
পরে (Android অ্যাপ আপডেটে): অ্যাপের API ঠিকানা connecttofriends.com/api করুন, তখন c2f ফায়ারওয়ালে বাইরের জন্য বন্ধ করা যাবে।
