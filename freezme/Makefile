API_URL     := http://16.170.31.58
WS_URL      := http://16.170.31.58
DART_DEFINE := --dart-define=API_BASE_URL=https://api.freezme.in

.PHONY: run build-ios build-android

run:
	flutter run $(DART_DEFINE)

build-ios:
	flutter build ios $(DART_DEFINE) --release

build-android:
	flutter build appbundle $(DART_DEFINE) --release
