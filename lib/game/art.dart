const backgroundAsset = 'assets/gameplay/background.webp';
const foundationAsset = 'assets/gameplay/foundation.webp';
const cloudAsset = 'assets/gameplay/cloud.webp';
const cloudAltAsset = 'assets/gameplay/cloud_alt.webp';
const craneAsset = 'assets/gameplay/crane.webp';
const hookAsset = 'assets/gameplay/hook.webp';
const plateAsset = 'assets/ui/plate.webp';
const allInAsset = 'assets/ui/all_in.webp';
const betAsset = 'assets/ui/bet.webp';
const buildAsset = 'assets/ui/build.webp';
const doubleAsset = 'assets/ui/double.webp';
const logoAsset = 'assets/branding/game_name.webp';
const loadingVerticalAsset = 'assets/loading/vertical.webp';
const loadingHorizontalAsset = 'assets/loading/horizontal.webp';

const blockAssets = <String>[
  'assets/gameplay/block_1.webp',
  'assets/gameplay/block_2.webp',
  'assets/gameplay/block_3.webp',
  'assets/gameplay/block_4.webp',
  'assets/gameplay/block_5.webp',
];

const blockAspects = <double>[
  384 / 508,
  413 / 508,
  413 / 508,
  489 / 494,
  489 / 494,
];

const blockHeightFactor = 0.27;
const foundationHeightFactor = 352 / 390;
const craneWidthOverHeight = 928 / 915;

const spriteAssets = <String>[
  logoAsset,
  loadingVerticalAsset,
  loadingHorizontalAsset,
  backgroundAsset,
  foundationAsset,
  cloudAsset,
  cloudAltAsset,
  craneAsset,
  hookAsset,
  plateAsset,
  allInAsset,
  betAsset,
  buildAsset,
  doubleAsset,
  ...blockAssets,
];

double blockWidthFactor(int art) => blockHeightFactor * blockAspects[art];
