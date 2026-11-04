import 'dart:collection';

class SlimCategory {
  const SlimCategory(this.id, this.name, this.description, this.downside,
      this.labels, {this.alwaysEnabled = const {}});

  final String id;
  final String name;
  final String description;
  final String downside;
  final List<String> labels;
  final Map<String, String> alwaysEnabled;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'downside': downside,
        'approxMemoryMB': 0,
        'labels': labels,
        if (alwaysEnabled.isNotEmpty)
          'alwaysEnabled': [
            for (final entry in alwaysEnabled.entries)
              {'label': entry.key, 'reason': entry.value}
          ],
      };
}

// This is an explicit mutation allowlist. Do not discover daemon labels from a
// simulator and add them dynamically: labels outside this catalog are never
// changed by simslim.
const categories = <SlimCategory>[
  SlimCategory('widgets', 'Widgets & Wallpaper',
      'Home and lock screen posters, widgets, and Live Activities.',
      'Widgets, wallpaper posters, and Live Activities stop updating.', [
    'com.apple.PosterBoard', 'com.apple.chronod', 'com.apple.liveactivitiesd',
    'com.apple.navd'
  ]),
  SlimCategory('siri', 'Siri & Intelligence',
      'Siri, Apple Intelligence, speech, and on-device ML model services.',
      'Siri, speech, and Apple Intelligence services are unavailable.', [
    'com.apple.assistant_cdmd', 'com.apple.assistant_service',
    'com.apple.siriactionsd', 'com.apple.siriinferenced',
    'com.apple.siriknowledged', 'com.apple.sirittsd',
    'com.apple.siri.context.service', 'com.apple.siri.acousticsignature',
    'com.apple.corespeechd', 'com.apple.voiced', 'com.apple.voicebankingd',
    'com.apple.speechmodeltrainingd', 'com.apple.intelligenceplatformd',
    'com.apple.intelligencecontextd', 'com.apple.intelligenceflowd',
    'com.apple.intelligencetasksd', 'com.apple.generativeexperiencesd',
    'com.apple.knowledgeconstructiond', 'com.apple.naturallanguaged',
    'com.apple.textunderstandingd', 'com.apple.modelcatalogd',
    'com.apple.modelmanagerd', 'com.apple.mlhostd', 'com.apple.mlruntimed',
    'com.apple.suggestd', 'com.apple.parsecd', 'com.apple.parsec-fbf',
    'com.apple.proactiveeventtrackerd'
  ], alwaysEnabled: {
    'com.apple.assistantd':
        'Hosts dictation; without it the system Spotlight app leaks memory.'
  }),
  SlimCategory('search', 'Spotlight & Search',
      'On-device Spotlight and in-Settings search services.',
      'Spotlight, Settings search, and Files Recents may fail.', [
    'com.apple.searchd', 'com.apple.searchtoold',
    'com.apple.spotlightknowledged', 'com.apple.spotlightknowledged.updater',
    'com.apple.corespotlightservice'
  ]),
  SlimCategory('icloud', 'iCloud & Apple Account',
      'iCloud sync, Apple Account, keychain, and backup services.',
      'iCloud sync, Apple Account, Keychain, and backup workflows will not work.', [
    'com.apple.appleaccountd', 'com.apple.appleaccounttransparencyd',
    'com.apple.appleidsetupd', 'com.apple.akd', 'com.apple.amsaccountsd',
    'com.apple.amsengagementd', 'com.apple.amsondevicestoraged',
    'com.apple.cloudd', 'com.apple.cloudphotod', 'com.apple.ckdiscretionaryd',
    'com.apple.cloudsettingssyncagent', 'com.apple.bird',
    'com.apple.syncdefaultsd', 'com.apple.cdpd', 'com.apple.sosd',
    'com.apple.SecureBackupDaemon', 'com.apple.TrustedPeersHelper',
    'com.apple.protectedcloudstorage.protectedcloudkeysyncing',
    'com.apple.icloudmailagent', 'com.apple.icloudsubscriptionoptimizerd',
    'com.apple.communicationtrustd'
  ]),
  SlimCategory('store', 'App Store, Push & Media',
      'App Store, push notification, StoreKit, and media services.',
      'Push notifications, StoreKit, and App Store testing will not work.', [
    'com.apple.appstored', 'com.apple.appstorecomponentsd', 'com.apple.apsd',
    'com.apple.itunescloudd', 'com.apple.itunesstored', 'com.apple.storekitd',
    'com.apple.amsaccountsd', 'com.apple.amsengagementd',
    'com.apple.amsondevicestoraged', 'com.apple.passd', 'com.apple.financed',
    'com.apple.videosubscriptionsd', 'com.apple.assetsubscriptiond',
    'com.apple.musicd'
  ]),
  SlimCategory('pim', 'Mail, Calendar & Contacts',
      'Mail, Calendar, Contacts, Reminders, and related sync services.',
      'Contacts, Calendar, Reminders, and Mail-backed pickers or sync may fail.', [
    'com.apple.email.maild', 'com.apple.exchangesyncd',
    'com.apple.dataaccess.dataaccessd', 'com.apple.calaccessd',
    'com.apple.remindd', 'com.apple.contactsd',
    'com.apple.contacts.postersyncd', 'com.apple.peopled'
  ]),
  SlimCategory('web', 'Safari Sync & Web Services',
      'Safari sync, web push, privacy, and universal-link services.',
      'Universal links, Safari sync, and background web services will not work.', [
    'com.apple.SafariBookmarksSyncAgent', 'com.apple.Safari.History',
    'com.apple.Safari.passwordbreachd', 'com.apple.Safari.SafeBrowsing.Service',
    'com.apple.safarifetcherd', 'com.apple.WebBookmarks.webbookmarksd',
    'com.apple.webkit.adattributiond', 'com.apple.webkit.webpushd',
    'com.apple.webprivacyd', 'com.apple.swcd'
  ]),
  SlimCategory('family', 'Family & Screen Time',
      'Family Sharing, Screen Time, and usage tracking.',
      'Family Sharing, Screen Time, and usage tracking stop working.', [
    'com.apple.familycircled', 'com.apple.FamilyControlsAgent',
    'com.apple.familynotification', 'com.apple.askpermissiond',
    'com.apple.asktod', 'com.apple.ScreenTimeAgent',
    'com.apple.ScreenTimeSettingsAgent', 'com.apple.UsageTrackingAgent'
  ]),
  SlimCategory('health', 'Health, Home & Fitness',
      'HealthKit, HomeKit, and Fitness services.',
      'HealthKit, HomeKit, and Fitness integrations will not work.', [
    'com.apple.healthd', 'com.apple.healthappd', 'com.apple.healthcontentd',
    'com.apple.healtheventsd', 'com.apple.healthrecordsd', 'com.apple.finhealthd',
    'com.apple.homed', 'com.apple.homeeventsd', 'com.apple.fitcore',
    'com.apple.fitcore.session', 'com.apple.fitnesscoachingd',
    'com.apple.fitnessintelligenced', 'com.apple.activityawardsd',
    'com.apple.activitysharingd'
  ]),
  SlimCategory('photos', 'Photos & Media Analysis',
      'Photos library, photo analysis, and media analysis services.',
      'Photo picker, Photos-library workflows, and media analysis may fail.', [
    'com.apple.photoanalysisd', 'com.apple.photosface', 'com.apple.mediaanalysisd',
    'com.apple.mediaanalysisd.service', 'com.apple.mediastream.mstreamd',
    'com.apple.medialibraryd', 'com.apple.assetsd', 'com.apple.assetsd.nebulad'
  ]),
  SlimCategory('apps', 'News, Weather, Maps & Games',
      'News, Weather, Maps, Tips, and game services.',
      'News, Weather, Maps background data, and game-controller services are unavailable.', [
    'com.apple.newsd', 'com.apple.weatherd', 'com.apple.Maps.mapssyncd',
    'com.apple.Maps.mapspushd', 'com.apple.Maps.geocorrectiond',
    'com.apple.maps.destinationd', 'com.apple.MapKit.SnapshotService',
    'com.apple.jetpackassetd', 'com.apple.tipsd', 'com.apple.gamesaved',
    'com.apple.GameController.gamecontrollerd'
  ], alwaysEnabled: {
    'com.apple.gamed': 'Required for timely XCUITest app launches (DTServiceHub / GameKit).'
  }),
  SlimCategory('messaging', 'Messaging & FaceTime',
      'iMessage, FaceTime, call, and identity services.',
      'iMessage, FaceTime, and related identity services will not work.', [
    'com.apple.identityservicesd', 'com.apple.ids_simd',
    'com.apple.imautomatichistorydeletionagent',
    'com.apple.imcore.imtransferagent',
    'com.apple.imdpersistence.IMDPersistenceAgent',
    'com.apple.facetimemessagestored',
    'com.apple.telephonyutilities.callservicesd'
  ]),
  SlimCategory('connectivity', 'Sharing & Device Connectivity',
      'AirDrop, Continuity, CarPlay, Watch, and Find My services.',
      'AirDrop, Continuity, CarPlay, Watch, and Find My connectivity will not work.', [
    'com.apple.rapportd', 'com.apple.companiond', 'com.apple.carkitd',
    'com.apple.wcd', 'com.apple.tvremoted', 'com.apple.avatarsd',
    'com.apple.stickersd', 'com.apple.sociallayerd', 'com.apple.announced',
    'com.apple.navd', 'com.apple.findmy.findmylocated'
  ], alwaysEnabled: {
    'com.apple.sharingd': 'Required for system share sheets.'
  }),
  SlimCategory('telemetry', 'Ads, Diagnostics & Telemetry',
      'DeviceCheck, ad privacy, analytics, diagnostics, and feedback services.',
      'DeviceCheck plus analytics, diagnostics, and feedback services are unavailable.', [
    'com.apple.ap.adprivacyd', 'com.apple.ap.promotedcontentd',
    'com.apple.diagnosticextensionsd', 'com.apple.feedbackd',
    'com.apple.rtcreportingd', 'com.apple.securityuploadd',
    'com.apple.geoanalyticsd', 'com.apple.triald', 'com.apple.followupd',
    'com.apple.purplebuddy.budd', 'com.apple.devicecheckd'
  ]),
  SlimCategory('mdm', 'Device Management',
      'Declarative device management and managed asset services.',
      'MDM and configuration-profile workflows that use these services will not work.', [
    'com.apple.remotemanagementd', 'com.apple.RemoteManagementAgent',
    'com.apple.managedassetsd'
  ]),
  SlimCategory('other', 'Other Background Services',
      'Wallet, App Clips, business services, assets, and miscellaneous daemons.',
      'Wallet, App Clips, accessibility asset downloads, and miscellaneous services are unavailable.', [
    'com.apple.financed', 'com.apple.passd', 'com.apple.merchantd',
    'com.apple.coreidvd', 'com.apple.businessservicesd',
    'com.apple.deviceaccessd', 'com.apple.replicatord', 'com.apple.linkd',
    'com.apple.ind', 'com.apple.storagedatad', 'com.apple.StatusKitAgent',
    'com.apple.countryd', 'com.apple.mobileassetd',
    'com.apple.managedconfiguration.passcodenagd',
    'com.apple.accessibility.axassetsd', 'com.apple.ClipServices.clipserviced'
  ]),
];

final categoryById = UnmodifiableMapView({for (final c in categories) c.id: c});
final slimmableLabels = UnmodifiableSetView({
  for (final c in categories) ...c.labels,
});
final managedLabels = UnmodifiableSetView({
  ...slimmableLabels,
  for (final c in categories) ...c.alwaysEnabled.keys,
});

const features = <String, (String, List<String>)>{
  'push': ('Push notifications', ['com.apple.apsd']),
  'storekit': ('StoreKit / in-app purchase', [
    'com.apple.storekitd', 'com.apple.itunesstored', 'com.apple.amsaccountsd',
    'com.apple.amsengagementd', 'com.apple.amsondevicestoraged',
    'com.apple.passd', 'com.apple.financed'
  ]),
  'app-store': ('App Store', ['com.apple.appstored', 'com.apple.itunesstored']),
  'universal-links': ('Universal links / associated domains', ['com.apple.swcd']),
  'spotlight': ('Spotlight & Settings search', ['com.apple.searchd', 'com.apple.searchtoold']),
  'files-recents': ('Files & document picker Recents', ['com.apple.searchd']),
  'siri': ('Siri & speech', ['com.apple.assistantd', 'com.apple.corespeechd']),
  'icloud': ('iCloud sync', ['com.apple.cloudd']),
  'keychain-sync': ('iCloud Keychain', ['com.apple.akd']),
  'contacts': ('Contacts', ['com.apple.contactsd']),
  'calendar': ('Calendar', ['com.apple.calaccessd']),
  'reminders': ('Reminders', ['com.apple.remindd']),
  'mail': ('Mail', ['com.apple.email.maild']),
  'photos': ('Photos library & analysis', ['com.apple.assetsd', 'com.apple.photoanalysisd']),
  'health': ('HealthKit', ['com.apple.healthd']),
  'homekit': ('HomeKit', ['com.apple.homed']),
  'imessage': ('iMessage & FaceTime', ['com.apple.identityservicesd']),
  'widgets': ('Widgets & Live Activities', ['com.apple.chronod', 'com.apple.liveactivitiesd', 'com.apple.navd']),
  'wallet': ('Wallet & passes', ['com.apple.passd']),
  'maps': ('Maps background services', ['com.apple.Maps.mapssyncd']),
  'weather': ('Weather', ['com.apple.weatherd']),
  'news': ('News', ['com.apple.newsd']),
  'game-center': ('Game Center', ['com.apple.gamed']),
  'find-my': ('Find My', ['com.apple.findmy.findmylocated']),
  'mdm': ('Declarative device management', ['com.apple.remotemanagementd', 'com.apple.RemoteManagementAgent']),
  'app-clips': ('App Clips', ['com.apple.ClipServices.clipserviced']),
  'screen-time': ('Screen Time', ['com.apple.ScreenTimeAgent']),
};

Set<String> splitList(String value) => value
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toSet();

Set<String> profileDisabled({Iterable<String> except = const [], Iterable<String> keep = const []}) {
  final keepEnabled = <String>{...keep};
  for (final id in except) {
    final category = categoryById[id];
    if (category == null) throw FormatException('unknown category "$id"');
    keepEnabled.addAll(category.labels);
  }
  return {...slimmableLabels}..removeAll(keepEnabled);
}

Set<String> desiredForPlatform(Set<String> desired, String platform) => {
      for (final label in desired)
        if (!(platform == 'watchOS' && label == 'com.apple.homed') &&
            !(platform == 'visionOS' && label == 'com.apple.mobileassetd'))
          label
    };

(Set<String>, Set<String>) delta(Set<String> current, Set<String> desired) => (
      desired.difference(current).intersection(managedLabels),
      current.difference(desired).intersection(managedLabels),
    );
