import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ============================================================
// AdMob Service — Production
// App ID     : ca-app-pub-4115564366785475~5279911679
// Ad Unit ID : ca-app-pub-4115564366785475/9740112422
//
// Règles Google AdMob strictement respectées :
// - Récompense UNIQUEMENT via onUserEarnedReward
// - Pub fermée avant la fin → PAS de récompense
// - Sur web : simulation (AdSense H5 gère les vraies pubs web)
// ============================================================

export 'admob_mobile.dart'
    if (dart.library.html) 'admob_web.dart';
