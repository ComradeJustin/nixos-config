import QtQuick
import Quickshell.Io
import "../.." as Root
import "../../components" as Components

// Searchable emoji picker for Spotlight.
// Grid layout, search by name/keyword, Enter or click copies to clipboard.
SpotlightProvider {
    id: emojiView
    implicitWidth: parent ? parent.width : 500
    implicitHeight: emojiContent.implicitHeight

    // ── Provider identity ──
    providerKey: "emoji"
    providerLabel: "Emoji"
    providerIcon: "󰞅"
    hasSearch: true
    hasGrid: true
    preferredWidth: 440
    preferredMaxHeight: 460

    // ── Grid geometry ──
    readonly property int cellSize: 40
    readonly property int columns: Math.floor((preferredWidth - 24) / cellSize)

    // ── State ──
    property string searchText: ""
    property int selectedIndex: 0
    property var filteredEmojis: []
    property string activeCategory: ""  // empty = all / search results

    // ── Provider interface ──
    function activate() {
        searchText = "";
        selectedIndex = 0;
        activeCategory = "";
        updateFilter();
    }
    function deactivate() {}

    function handleSearchText(text) {
        searchText = text.toLowerCase();
        selectedIndex = 0;
        activeCategory = "";
        updateFilter();
    }

    function moveUp() {
        var ni = selectedIndex - columns;
        if (ni >= 0) selectedIndex = ni;
        emojiFlick.ensureVisible(selectedIndex);
    }
    function moveDown() {
        var ni = selectedIndex + columns;
        if (ni < filteredEmojis.length) selectedIndex = ni;
        emojiFlick.ensureVisible(selectedIndex);
    }
    function moveLeft() {
        if (selectedIndex > 0) selectedIndex--;
        emojiFlick.ensureVisible(selectedIndex);
    }
    function moveRight() {
        if (selectedIndex < filteredEmojis.length - 1) selectedIndex++;
        emojiFlick.ensureVisible(selectedIndex);
    }

    function accept() {
        if (filteredEmojis.length > 0 && selectedIndex < filteredEmojis.length) {
            var emoji = filteredEmojis[selectedIndex];
            copyProc.command = ["wl-copy", emoji.e];
            copyProc.running = true;

            // Add to recent
            var r = _recentEmojis.slice();
            r = r.filter(function(x) { return x.e !== emoji.e; });
            r.unshift(emoji);
            if (r.length > 24) r = r.slice(0, 24);
            _recentEmojis = r;
        }
    }

    // ── Filter logic ──
    function updateFilter() {
        var src = searchText !== "" ? _allEmojis : (activeCategory !== "" ? _emojisByCategory(activeCategory) : _allEmojis);
        if (searchText === "") {
            // Show recent first, then all
            if (_recentEmojis.length > 0 && activeCategory === "") {
                filteredEmojis = _recentEmojis.concat(_allEmojis);
            } else {
                filteredEmojis = src;
            }
        } else {
            var q = searchText;
            filteredEmojis = src.filter(function(em) {
                return em.n.indexOf(q) !== -1 || em.k.indexOf(q) !== -1;
            });
        }
        resultCount = filteredEmojis.length;
        totalCount = _allEmojis.length;
    }

    function _emojisByCategory(cat) {
        return _allEmojis.filter(function(em) { return em.c === cat; });
    }

    property var _recentEmojis: []

    Process {
        id: copyProc
        command: ["wl-copy", ""]
    }

    // ── Categories for the category bar ──
    readonly property var _categories: [
        { key: "",        icon: "󰥨", label: "All" },
        { key: "smileys", icon: "😀", label: "Smileys" },
        { key: "people",  icon: "👋", label: "People" },
        { key: "nature",  icon: "🌿", label: "Nature" },
        { key: "food",    icon: "🍕", label: "Food" },
        { key: "travel",  icon: "✈", label: "Travel" },
        { key: "objects", icon: "💡", label: "Objects" },
        { key: "symbols", icon: "❤", label: "Symbols" },
        { key: "flags",   icon: "🏁", label: "Flags" }
    ]

    // ── Emoji data ──
    // Compact format: e=emoji, n=name, k=keywords, c=category
    readonly property var _allEmojis: [
        // ── Smileys ──
        { e: "😀", n: "grinning face", k: "happy smile grin", c: "smileys" },
        { e: "😁", n: "beaming face", k: "happy grin teeth", c: "smileys" },
        { e: "😂", n: "face with tears of joy", k: "laugh crying lol", c: "smileys" },
        { e: "🤣", n: "rolling on the floor laughing", k: "rofl lmao", c: "smileys" },
        { e: "😃", n: "grinning face big eyes", k: "happy smile", c: "smileys" },
        { e: "😄", n: "grinning face smiling eyes", k: "happy smile", c: "smileys" },
        { e: "😅", n: "grinning face sweat", k: "nervous laugh", c: "smileys" },
        { e: "😆", n: "grinning squinting face", k: "laugh xd", c: "smileys" },
        { e: "😉", n: "winking face", k: "wink flirt", c: "smileys" },
        { e: "😊", n: "smiling face smiling eyes", k: "happy blush", c: "smileys" },
        { e: "😋", n: "face savoring food", k: "yummy delicious", c: "smileys" },
        { e: "😎", n: "smiling face sunglasses", k: "cool sunglasses", c: "smileys" },
        { e: "😍", n: "smiling face heart eyes", k: "love heart", c: "smileys" },
        { e: "🥰", n: "smiling face hearts", k: "love adore", c: "smileys" },
        { e: "😘", n: "face blowing kiss", k: "kiss love", c: "smileys" },
        { e: "😗", n: "kissing face", k: "kiss", c: "smileys" },
        { e: "😙", n: "kissing face smiling eyes", k: "kiss", c: "smileys" },
        { e: "🥲", n: "smiling face tear", k: "sad happy bittersweet", c: "smileys" },
        { e: "😏", n: "smirking face", k: "smirk suggestive", c: "smileys" },
        { e: "😌", n: "relieved face", k: "relieved peaceful", c: "smileys" },
        { e: "😔", n: "pensive face", k: "sad pensive", c: "smileys" },
        { e: "😴", n: "sleeping face", k: "sleep zzz tired", c: "smileys" },
        { e: "🤤", n: "drooling face", k: "drool", c: "smileys" },
        { e: "😷", n: "face with medical mask", k: "sick mask covid", c: "smileys" },
        { e: "🤒", n: "face thermometer", k: "sick fever", c: "smileys" },
        { e: "🤕", n: "face head bandage", k: "hurt injured", c: "smileys" },
        { e: "🤢", n: "nauseated face", k: "sick vomit", c: "smileys" },
        { e: "🤮", n: "face vomiting", k: "sick puke", c: "smileys" },
        { e: "🤧", n: "sneezing face", k: "sneeze sick cold", c: "smileys" },
        { e: "🥵", n: "hot face", k: "hot warm sweat", c: "smileys" },
        { e: "🥶", n: "cold face", k: "cold freezing", c: "smileys" },
        { e: "😱", n: "face screaming fear", k: "scared horror", c: "smileys" },
        { e: "😨", n: "fearful face", k: "scared fear", c: "smileys" },
        { e: "😰", n: "anxious face sweat", k: "nervous anxious", c: "smileys" },
        { e: "😥", n: "sad but relieved", k: "sad relieved sweat", c: "smileys" },
        { e: "😢", n: "crying face", k: "sad cry tear", c: "smileys" },
        { e: "😭", n: "loudly crying face", k: "sob crying", c: "smileys" },
        { e: "😤", n: "face steam from nose", k: "angry triumph", c: "smileys" },
        { e: "😠", n: "angry face", k: "angry mad", c: "smileys" },
        { e: "😡", n: "pouting face", k: "angry rage", c: "smileys" },
        { e: "🤬", n: "face with symbols mouth", k: "swearing cursing", c: "smileys" },
        { e: "🥺", n: "pleading face", k: "puppy eyes beg please", c: "smileys" },
        { e: "😳", n: "flushed face", k: "embarrassed blush", c: "smileys" },
        { e: "🤯", n: "exploding head", k: "mind blown shock", c: "smileys" },
        { e: "😶", n: "face without mouth", k: "silence mute", c: "smileys" },
        { e: "🫠", n: "melting face", k: "melt dissolve", c: "smileys" },
        { e: "🫡", n: "saluting face", k: "salute respect", c: "smileys" },
        { e: "🤔", n: "thinking face", k: "think hmm", c: "smileys" },
        { e: "🫣", n: "face with peeking eye", k: "peek shy", c: "smileys" },
        { e: "🤭", n: "face with hand over mouth", k: "oops giggle", c: "smileys" },
        { e: "🫢", n: "face open eyes hand over mouth", k: "surprise gasp", c: "smileys" },
        { e: "🤫", n: "shushing face", k: "quiet shh secret", c: "smileys" },
        { e: "🙄", n: "face with rolling eyes", k: "eyeroll whatever", c: "smileys" },
        { e: "😬", n: "grimacing face", k: "awkward cringe", c: "smileys" },
        { e: "🫥", n: "dotted line face", k: "invisible hidden", c: "smileys" },
        { e: "😮‍💨", n: "face exhaling", k: "sigh relief", c: "smileys" },
        { e: "🤥", n: "lying face", k: "lie pinocchio", c: "smileys" },
        { e: "🙃", n: "upside down face", k: "sarcasm silly", c: "smileys" },
        { e: "🫤", n: "face with diagonal mouth", k: "meh skeptical", c: "smileys" },
        { e: "💀", n: "skull", k: "dead death skeleton", c: "smileys" },
        { e: "👻", n: "ghost", k: "spooky halloween", c: "smileys" },
        { e: "👽", n: "alien", k: "ufo space extraterrestrial", c: "smileys" },
        { e: "🤖", n: "robot", k: "bot android machine", c: "smileys" },
        { e: "🎃", n: "jack o lantern", k: "halloween pumpkin", c: "smileys" },
        { e: "😈", n: "smiling face horns", k: "devil evil", c: "smileys" },
        { e: "💩", n: "pile of poo", k: "poop crap", c: "smileys" },
        { e: "🤡", n: "clown face", k: "clown joker", c: "smileys" },

        // ── People & Gestures ──
        { e: "👋", n: "waving hand", k: "wave hello bye", c: "people" },
        { e: "🤚", n: "raised back hand", k: "stop hand", c: "people" },
        { e: "✋", n: "raised hand", k: "stop high five", c: "people" },
        { e: "🖖", n: "vulcan salute", k: "spock star trek", c: "people" },
        { e: "👌", n: "ok hand", k: "ok perfect fine", c: "people" },
        { e: "🤌", n: "pinched fingers", k: "italian chef kiss", c: "people" },
        { e: "🤏", n: "pinching hand", k: "small tiny little", c: "people" },
        { e: "✌", n: "victory hand", k: "peace sign", c: "people" },
        { e: "🤞", n: "crossed fingers", k: "luck hope", c: "people" },
        { e: "🫰", n: "hand with index finger and thumb crossed", k: "money snap", c: "people" },
        { e: "🤟", n: "love you gesture", k: "rock ily", c: "people" },
        { e: "🤘", n: "sign of horns", k: "rock metal", c: "people" },
        { e: "🤙", n: "call me hand", k: "shaka call phone", c: "people" },
        { e: "👈", n: "pointing left", k: "left point", c: "people" },
        { e: "👉", n: "pointing right", k: "right point", c: "people" },
        { e: "👆", n: "pointing up", k: "up point", c: "people" },
        { e: "👇", n: "pointing down", k: "down point", c: "people" },
        { e: "☝", n: "index pointing up", k: "one point", c: "people" },
        { e: "👍", n: "thumbs up", k: "like approve yes good", c: "people" },
        { e: "👎", n: "thumbs down", k: "dislike disapprove no bad", c: "people" },
        { e: "✊", n: "raised fist", k: "power solidarity", c: "people" },
        { e: "👊", n: "oncoming fist", k: "punch bump", c: "people" },
        { e: "🤛", n: "left facing fist", k: "fist bump", c: "people" },
        { e: "🤜", n: "right facing fist", k: "fist bump", c: "people" },
        { e: "👏", n: "clapping hands", k: "clap applause bravo", c: "people" },
        { e: "🙌", n: "raising hands", k: "celebration hooray", c: "people" },
        { e: "🫶", n: "heart hands", k: "love heart gesture", c: "people" },
        { e: "👐", n: "open hands", k: "open hands", c: "people" },
        { e: "🤲", n: "palms up together", k: "prayer receive", c: "people" },
        { e: "🤝", n: "handshake", k: "deal agreement shake", c: "people" },
        { e: "🙏", n: "folded hands", k: "pray please thank you namaste", c: "people" },
        { e: "💪", n: "flexed biceps", k: "strong muscle power", c: "people" },
        { e: "🫵", n: "index pointing at viewer", k: "you point", c: "people" },
        { e: "🖕", n: "middle finger", k: "flip off", c: "people" },
        { e: "🫳", n: "palm down hand", k: "drop dismiss", c: "people" },
        { e: "🫴", n: "palm up hand", k: "offer give", c: "people" },

        // ── Nature & Animals ──
        { e: "🐶", n: "dog face", k: "dog puppy pet", c: "nature" },
        { e: "🐱", n: "cat face", k: "cat kitten pet", c: "nature" },
        { e: "🐭", n: "mouse face", k: "mouse rat", c: "nature" },
        { e: "🐹", n: "hamster", k: "hamster pet", c: "nature" },
        { e: "🐰", n: "rabbit face", k: "rabbit bunny", c: "nature" },
        { e: "🦊", n: "fox", k: "fox", c: "nature" },
        { e: "🐻", n: "bear", k: "bear", c: "nature" },
        { e: "🐼", n: "panda", k: "panda bear", c: "nature" },
        { e: "🐸", n: "frog", k: "frog toad", c: "nature" },
        { e: "🐵", n: "monkey face", k: "monkey ape", c: "nature" },
        { e: "🐔", n: "chicken", k: "chicken hen", c: "nature" },
        { e: "🐧", n: "penguin", k: "penguin", c: "nature" },
        { e: "🐦", n: "bird", k: "bird", c: "nature" },
        { e: "🦅", n: "eagle", k: "eagle bird", c: "nature" },
        { e: "🦆", n: "duck", k: "duck", c: "nature" },
        { e: "🦉", n: "owl", k: "owl wise", c: "nature" },
        { e: "🐺", n: "wolf", k: "wolf", c: "nature" },
        { e: "🐗", n: "boar", k: "boar pig", c: "nature" },
        { e: "🐴", n: "horse face", k: "horse", c: "nature" },
        { e: "🦄", n: "unicorn", k: "unicorn magic", c: "nature" },
        { e: "🐝", n: "honeybee", k: "bee honey", c: "nature" },
        { e: "🐛", n: "bug", k: "bug insect", c: "nature" },
        { e: "🦋", n: "butterfly", k: "butterfly pretty", c: "nature" },
        { e: "🐌", n: "snail", k: "snail slow", c: "nature" },
        { e: "🐙", n: "octopus", k: "octopus", c: "nature" },
        { e: "🦑", n: "squid", k: "squid", c: "nature" },
        { e: "🐠", n: "tropical fish", k: "fish", c: "nature" },
        { e: "🐬", n: "dolphin", k: "dolphin", c: "nature" },
        { e: "🐳", n: "whale", k: "whale", c: "nature" },
        { e: "🦈", n: "shark", k: "shark", c: "nature" },
        { e: "🐊", n: "crocodile", k: "crocodile alligator", c: "nature" },
        { e: "🐆", n: "leopard", k: "leopard cheetah", c: "nature" },
        { e: "🦁", n: "lion", k: "lion king", c: "nature" },
        { e: "🐘", n: "elephant", k: "elephant", c: "nature" },
        { e: "🦒", n: "giraffe", k: "giraffe tall", c: "nature" },
        { e: "🐍", n: "snake", k: "snake python", c: "nature" },
        { e: "🌸", n: "cherry blossom", k: "flower spring sakura", c: "nature" },
        { e: "🌹", n: "rose", k: "flower rose love", c: "nature" },
        { e: "🌻", n: "sunflower", k: "flower sun", c: "nature" },
        { e: "🌺", n: "hibiscus", k: "flower tropical", c: "nature" },
        { e: "🌿", n: "herb", k: "plant leaf herb", c: "nature" },
        { e: "🍀", n: "four leaf clover", k: "luck clover", c: "nature" },
        { e: "🌲", n: "evergreen tree", k: "tree pine", c: "nature" },
        { e: "🌴", n: "palm tree", k: "tree palm tropical", c: "nature" },
        { e: "🌈", n: "rainbow", k: "rainbow", c: "nature" },
        { e: "⭐", n: "star", k: "star", c: "nature" },
        { e: "🌙", n: "crescent moon", k: "moon night", c: "nature" },
        { e: "☀", n: "sun", k: "sun sunny", c: "nature" },
        { e: "🔥", n: "fire", k: "fire hot flame lit", c: "nature" },
        { e: "💧", n: "droplet", k: "water drop", c: "nature" },
        { e: "❄", n: "snowflake", k: "snow cold winter", c: "nature" },
        { e: "⚡", n: "lightning", k: "lightning zap thunder electric", c: "nature" },

        // ── Food & Drink ──
        { e: "🍎", n: "red apple", k: "apple fruit", c: "food" },
        { e: "🍊", n: "tangerine", k: "orange fruit", c: "food" },
        { e: "🍋", n: "lemon", k: "lemon citrus", c: "food" },
        { e: "🍌", n: "banana", k: "banana fruit", c: "food" },
        { e: "🍉", n: "watermelon", k: "watermelon fruit", c: "food" },
        { e: "🍇", n: "grapes", k: "grapes wine", c: "food" },
        { e: "🍓", n: "strawberry", k: "strawberry berry", c: "food" },
        { e: "🫐", n: "blueberries", k: "blueberry berry", c: "food" },
        { e: "🍑", n: "peach", k: "peach fruit butt", c: "food" },
        { e: "🥑", n: "avocado", k: "avocado guac", c: "food" },
        { e: "🍕", n: "pizza", k: "pizza slice", c: "food" },
        { e: "🍔", n: "hamburger", k: "burger hamburger", c: "food" },
        { e: "🌮", n: "taco", k: "taco mexican", c: "food" },
        { e: "🌯", n: "burrito", k: "burrito wrap", c: "food" },
        { e: "🍟", n: "french fries", k: "fries chips", c: "food" },
        { e: "🍗", n: "poultry leg", k: "chicken drumstick", c: "food" },
        { e: "🥩", n: "cut of meat", k: "steak meat", c: "food" },
        { e: "🍣", n: "sushi", k: "sushi japanese fish", c: "food" },
        { e: "🍜", n: "steaming bowl", k: "ramen noodles soup", c: "food" },
        { e: "🍝", n: "spaghetti", k: "pasta italian", c: "food" },
        { e: "🍰", n: "shortcake", k: "cake dessert", c: "food" },
        { e: "🎂", n: "birthday cake", k: "cake birthday", c: "food" },
        { e: "🍩", n: "doughnut", k: "donut sweet", c: "food" },
        { e: "🍪", n: "cookie", k: "cookie biscuit", c: "food" },
        { e: "🍫", n: "chocolate bar", k: "chocolate candy", c: "food" },
        { e: "🍿", n: "popcorn", k: "popcorn movie", c: "food" },
        { e: "☕", n: "coffee", k: "coffee cafe hot", c: "food" },
        { e: "🍵", n: "teacup", k: "tea green", c: "food" },
        { e: "🧋", n: "bubble tea", k: "boba tea", c: "food" },
        { e: "🍺", n: "beer mug", k: "beer drink", c: "food" },
        { e: "🍻", n: "clinking beer mugs", k: "beer cheers", c: "food" },
        { e: "🥂", n: "clinking glasses", k: "champagne toast cheers", c: "food" },
        { e: "🍷", n: "wine glass", k: "wine red", c: "food" },
        { e: "🥤", n: "cup with straw", k: "soda drink", c: "food" },

        // ── Travel & Places ──
        { e: "🚗", n: "automobile", k: "car drive", c: "travel" },
        { e: "🚕", n: "taxi", k: "taxi cab", c: "travel" },
        { e: "🚀", n: "rocket", k: "rocket space launch", c: "travel" },
        { e: "✈", n: "airplane", k: "plane flight travel", c: "travel" },
        { e: "🚂", n: "locomotive", k: "train steam", c: "travel" },
        { e: "🚢", n: "ship", k: "ship boat cruise", c: "travel" },
        { e: "🏠", n: "house", k: "house home", c: "travel" },
        { e: "🏢", n: "office building", k: "office building work", c: "travel" },
        { e: "🏥", n: "hospital", k: "hospital medical", c: "travel" },
        { e: "🏫", n: "school", k: "school education", c: "travel" },
        { e: "⛪", n: "church", k: "church religion", c: "travel" },
        { e: "🗼", n: "tokyo tower", k: "tower tokyo", c: "travel" },
        { e: "🏰", n: "castle", k: "castle european", c: "travel" },
        { e: "🗽", n: "statue of liberty", k: "liberty statue new york", c: "travel" },
        { e: "🌍", n: "globe europe africa", k: "earth world globe", c: "travel" },
        { e: "🌎", n: "globe americas", k: "earth world globe", c: "travel" },
        { e: "🌏", n: "globe asia australia", k: "earth world globe", c: "travel" },
        { e: "🏔", n: "snow capped mountain", k: "mountain snow", c: "travel" },
        { e: "🏖", n: "beach umbrella", k: "beach vacation", c: "travel" },
        { e: "🏕", n: "camping", k: "camping tent", c: "travel" },

        // ── Objects ──
        { e: "💻", n: "laptop", k: "computer laptop", c: "objects" },
        { e: "🖥", n: "desktop computer", k: "computer desktop monitor", c: "objects" },
        { e: "⌨", n: "keyboard", k: "keyboard typing", c: "objects" },
        { e: "🖱", n: "computer mouse", k: "mouse click", c: "objects" },
        { e: "📱", n: "mobile phone", k: "phone mobile cell", c: "objects" },
        { e: "📷", n: "camera", k: "camera photo", c: "objects" },
        { e: "📹", n: "video camera", k: "camera video record", c: "objects" },
        { e: "🎮", n: "video game", k: "game controller gaming", c: "objects" },
        { e: "🕹", n: "joystick", k: "game joystick arcade", c: "objects" },
        { e: "🎧", n: "headphone", k: "headphones music audio", c: "objects" },
        { e: "🎵", n: "musical note", k: "music note", c: "objects" },
        { e: "🎶", n: "musical notes", k: "music notes", c: "objects" },
        { e: "🎤", n: "microphone", k: "mic karaoke", c: "objects" },
        { e: "🎸", n: "guitar", k: "guitar music rock", c: "objects" },
        { e: "🎹", n: "musical keyboard", k: "piano keyboard music", c: "objects" },
        { e: "📚", n: "books", k: "books reading library", c: "objects" },
        { e: "📖", n: "open book", k: "book read", c: "objects" },
        { e: "📝", n: "memo", k: "note write pencil", c: "objects" },
        { e: "✏", n: "pencil", k: "pencil write", c: "objects" },
        { e: "🔑", n: "key", k: "key lock password", c: "objects" },
        { e: "🔒", n: "locked", k: "lock security", c: "objects" },
        { e: "🔓", n: "unlocked", k: "unlock open", c: "objects" },
        { e: "💡", n: "light bulb", k: "idea bulb light", c: "objects" },
        { e: "🔧", n: "wrench", k: "tool wrench fix", c: "objects" },
        { e: "🔨", n: "hammer", k: "tool hammer build", c: "objects" },
        { e: "⚙", n: "gear", k: "settings gear cog", c: "objects" },
        { e: "💰", n: "money bag", k: "money rich dollar", c: "objects" },
        { e: "💳", n: "credit card", k: "card payment", c: "objects" },
        { e: "📦", n: "package", k: "package box shipping", c: "objects" },
        { e: "🎁", n: "wrapped gift", k: "gift present birthday", c: "objects" },
        { e: "🏆", n: "trophy", k: "trophy winner award", c: "objects" },
        { e: "🎯", n: "bullseye", k: "target direct hit", c: "objects" },
        { e: "🧲", n: "magnet", k: "magnet attract", c: "objects" },
        { e: "🪄", n: "magic wand", k: "magic wand wizard", c: "objects" },
        { e: "💎", n: "gem stone", k: "diamond gem jewel", c: "objects" },

        // ── Symbols ──
        { e: "❤", n: "red heart", k: "heart love red", c: "symbols" },
        { e: "🧡", n: "orange heart", k: "heart love orange", c: "symbols" },
        { e: "💛", n: "yellow heart", k: "heart love yellow", c: "symbols" },
        { e: "💚", n: "green heart", k: "heart love green", c: "symbols" },
        { e: "💙", n: "blue heart", k: "heart love blue", c: "symbols" },
        { e: "💜", n: "purple heart", k: "heart love purple", c: "symbols" },
        { e: "🖤", n: "black heart", k: "heart love black", c: "symbols" },
        { e: "🤍", n: "white heart", k: "heart love white", c: "symbols" },
        { e: "💔", n: "broken heart", k: "heart broken sad", c: "symbols" },
        { e: "💯", n: "hundred points", k: "100 perfect score", c: "symbols" },
        { e: "💢", n: "anger symbol", k: "angry", c: "symbols" },
        { e: "💥", n: "collision", k: "boom explosion", c: "symbols" },
        { e: "💫", n: "dizzy", k: "star dizzy", c: "symbols" },
        { e: "💬", n: "speech balloon", k: "speech chat talk bubble", c: "symbols" },
        { e: "💭", n: "thought balloon", k: "thought think bubble", c: "symbols" },
        { e: "✅", n: "check mark button", k: "check done yes", c: "symbols" },
        { e: "❌", n: "cross mark", k: "no wrong x", c: "symbols" },
        { e: "❓", n: "question mark", k: "question", c: "symbols" },
        { e: "❗", n: "exclamation mark", k: "exclamation important", c: "symbols" },
        { e: "⚠", n: "warning", k: "warning caution", c: "symbols" },
        { e: "🚫", n: "prohibited", k: "no forbidden stop", c: "symbols" },
        { e: "♻", n: "recycling symbol", k: "recycle green", c: "symbols" },
        { e: "✨", n: "sparkles", k: "sparkle glitter magic new", c: "symbols" },
        { e: "🎉", n: "party popper", k: "party celebrate tada", c: "symbols" },
        { e: "🎊", n: "confetti ball", k: "party celebrate", c: "symbols" },
        { e: "🏳️‍🌈", n: "rainbow flag", k: "pride lgbtq rainbow", c: "symbols" },
        { e: "⬆", n: "up arrow", k: "arrow up", c: "symbols" },
        { e: "⬇", n: "down arrow", k: "arrow down", c: "symbols" },
        { e: "⬅", n: "left arrow", k: "arrow left", c: "symbols" },
        { e: "➡", n: "right arrow", k: "arrow right", c: "symbols" },
        { e: "🔄", n: "counterclockwise arrows", k: "refresh reload", c: "symbols" },
        { e: "ℹ", n: "information", k: "info information", c: "symbols" },
        { e: "🆕", n: "new button", k: "new", c: "symbols" },
        { e: "🆗", n: "ok button", k: "ok", c: "symbols" },
        { e: "🔴", n: "red circle", k: "circle red", c: "symbols" },
        { e: "🟢", n: "green circle", k: "circle green", c: "symbols" },
        { e: "🔵", n: "blue circle", k: "circle blue", c: "symbols" },
        { e: "⚫", n: "black circle", k: "circle black", c: "symbols" },
        { e: "⚪", n: "white circle", k: "circle white", c: "symbols" },

        // ── Flags ──
        { e: "🇺🇸", n: "united states", k: "usa us america flag", c: "flags" },
        { e: "🇬🇧", n: "united kingdom", k: "uk britain england flag", c: "flags" },
        { e: "🇫🇷", n: "france", k: "france french flag", c: "flags" },
        { e: "🇩🇪", n: "germany", k: "germany german flag", c: "flags" },
        { e: "🇯🇵", n: "japan", k: "japan japanese flag", c: "flags" },
        { e: "🇰🇷", n: "south korea", k: "korea korean flag", c: "flags" },
        { e: "🇨🇳", n: "china", k: "china chinese flag", c: "flags" },
        { e: "🇮🇳", n: "india", k: "india indian flag", c: "flags" },
        { e: "🇧🇷", n: "brazil", k: "brazil brazilian flag", c: "flags" },
        { e: "🇨🇦", n: "canada", k: "canada canadian flag maple", c: "flags" },
        { e: "🇦🇺", n: "australia", k: "australia australian flag", c: "flags" },
        { e: "🇲🇽", n: "mexico", k: "mexico mexican flag", c: "flags" },
        { e: "🇪🇸", n: "spain", k: "spain spanish flag", c: "flags" },
        { e: "🇮🇹", n: "italy", k: "italy italian flag", c: "flags" },
        { e: "🇷🇺", n: "russia", k: "russia russian flag", c: "flags" },
        { e: "🇵🇭", n: "philippines", k: "philippines filipino flag", c: "flags" },
        { e: "🏴‍☠️", n: "pirate flag", k: "pirate jolly roger", c: "flags" }
    ]

    // ── Visual ──
    Column {
        id: emojiContent
        width: parent.width
        spacing: 0

        // ── Category bar ──
        Item {
            width: parent.width
            height: 36
            visible: emojiView.searchText === ""

            Row {
                anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
                spacing: 2

                Repeater {
                    model: emojiView._categories
                    Rectangle {
                        required property var modelData
                        width: 36; height: 28
                        radius: Root.Theme.radiusSmall
                        color: emojiView.activeCategory === modelData.key
                            ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.15)
                            : catMouse.containsMouse
                                ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.06)
                                : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font { family: Root.Theme.fontFamily; pixelSize: 14 }
                            color: emojiView.activeCategory === modelData.key ? Root.Theme.accentPrimary : Root.Theme.textDimmed
                        }

                        MouseArea {
                            id: catMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                emojiView.activeCategory = modelData.key;
                                emojiView.selectedIndex = 0;
                                emojiView.updateFilter();
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width - 24; height: 1
            color: Root.Theme.textDimmed; opacity: 0.15
            anchors.horizontalCenter: parent.horizontalCenter
            visible: emojiView.searchText === ""
        }

        // ── Emoji grid ──
        Components.SmoothFlickable {
            id: emojiFlick
            width: parent.width
            height: Math.min(contentHeight, emojiView.maxContentHeight - (emojiView.searchText === "" ? 37 : 0))
            contentHeight: emojiGrid.height + 16
            clip: true

            function ensureVisible(idx) {
                var row = Math.floor(idx / emojiView.columns);
                var rowY = row * emojiView.cellSize + 8;
                if (rowY < contentY) contentY = rowY;
                else if (rowY + emojiView.cellSize > contentY + height)
                    contentY = rowY + emojiView.cellSize - height;
            }

            Grid {
                id: emojiGrid
                columns: emojiView.columns
                anchors { top: parent.top; topMargin: 8; horizontalCenter: parent.horizontalCenter }
                spacing: 0

                Repeater {
                    model: emojiView.filteredEmojis

                    Rectangle {
                        required property var modelData
                        required property int index
                        width: emojiView.cellSize
                        height: emojiView.cellSize
                        radius: Root.Theme.radiusSmall
                        color: index === emojiView.selectedIndex
                            ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.15)
                            : emojiMouse.containsMouse
                                ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.06)
                                : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.e
                            font.pixelSize: 22
                        }

                        MouseArea {
                            id: emojiMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                emojiView.selectedIndex = index;
                                emojiView.accept();
                            }
                        }
                    }
                }
            }
        }

        // ── Selected emoji name footer ──
        Item {
            width: parent.width
            height: 28
            visible: emojiView.filteredEmojis.length > 0

            Text {
                anchors { centerIn: parent }
                text: {
                    if (emojiView.filteredEmojis.length === 0) return "";
                    var em = emojiView.filteredEmojis[emojiView.selectedIndex];
                    return em ? (em.e + "  " + em.n) : "";
                }
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: 11 }
                opacity: 0.6
            }
        }

        // ── Empty state ──
        Item {
            width: parent.width
            height: 80
            visible: emojiView.filteredEmojis.length === 0

            Text {
                anchors.centerIn: parent
                text: "No emoji found"
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: 12 }
                opacity: 0.5
            }
        }

        Item { width: 1; height: 4 }
    }
}
