/**
   MoeCoop
   Copyright (C) 2016  Mojo

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
module coop.model.item;

import std.algorithm;
import std.conv;
import std.exception;
import std.file;
import std.json;
import std.math;
import std.range;
import std.traits;
import std.typecons;
import std.variant;

import coop.util;

alias ExtraInfo = Algebraic!(FoodInfo, WeaponInfo, BulletInfo, MedicineInfo);

/// アイテム一般の情報
struct Item
{
    this(this)
    {
        petFoodInfo = petFoodInfo.dup;
    }

    dstring name;
    dstring ename;
    real weight;
    uint price;
    dstring info;
    ushort properties;
    bool transferable;
    bool stackable;
    real[PetFoodType] petFoodInfo;
    dstring remarks;
    ItemType type;

    auto toJSON()
    {
        auto hash = [
            "英名": JSONValue(ename.to!string),
            "NPC売却価格": JSONValue(price),
            "重さ": JSONValue(weight.isNaN ? 0 : weight),
            "info": JSONValue(info.to!string),
            "転送できる": JSONValue(transferable),
            "スタックできる": JSONValue(stackable),
            "種類": JSONValue(type.to!string),
            ];

        assert(petFoodInfo.keys.length == 1);
        if (petFoodInfo.keys[0] != PetFoodType.NoEatable)
        {
            hash["ペットアイテム"] = JSONValue(petFoodInfo.to!(real[string]));
        }

        if (properties)
        {
            hash["特殊条件"] = JSONValue(properties.toStrings(false));
        }
        return JSONValue(hash);
    }

    auto opEquals(const typeof(this) other)
    {
        auto prop(string p)(in typeof(this) item)
        {
            return mixin("item."~p);
        }
        foreach(field; FieldNameTuple!(typeof(this)))
        {
            static if (field == "weight")
            {
                import std.math;
                if (!prop!field(this).isNaN && !prop!field(other).isNaN &&
                    !prop!field(this).approxEqual(prop!field(other)))
                {
                    return false;
                }
                else if (prop!field(this).isNaN ^ prop!field(other).isNaN)
                {
                    return false;
                }
            }
            else
            {
                if (prop!field(this) != prop!field(other))
                {
                    return false;
                }
            }
        }
        return true;
    }
}

auto readItems(string fname)
{
    auto res = fname.readText.parseJSON;
    enforce(res.type == JSON_TYPE.OBJECT);
    auto items = res.object;
    return items.keys.map!(key =>
                           tuple(key.to!dstring,
                                 key.toItem(items[key].object)));
}

auto toItem(string s, JSONValue[string] json)
{
    Item item;
    with(item)
    {
        name = s.to!dstring;
        ename = json["英名"].jto!dstring;
        price = json["NPC売却価格"].jto!uint;
        weight = json["重さ"].jto!real;
        info = json["info"].jto!dstring;
        transferable = json["転送できる"].jto!bool;
        stackable = json["スタックできる"].jto!bool;

        if (auto petFood = "ペットアイテム" in json)
        {
            petFoodInfo = (*petFood).jto!(real[PetFoodType]);
        }
        else
        {
            petFoodInfo = [PetFoodType.NoEatable.to!PetFoodType: 0];
        }

        if (auto props = "特殊条件" in json)
        {
            properties = (*props).array.toSpecialProperties;
        }
        type = json["種類"].jto!ItemType;
    }
    return item;
}

alias PetFoodType = ExtendedEnum!(["UNKNOWN", "Food", "Meat", "Weed", "Drink", "Liquor", "Medicine", "Metal",
                                   "Stone", "Bone", "Crystal", "Wood", "Leather", "Paper", "Cloth", "Others", "NoEatable"],
                                  ["不明", "食べ物", "肉食物", "草食物", "飲み物", "酒", "薬", "金属",
                                   "石", "骨", "クリスタル", "木", "皮", "紙", "布", "その他", "犬も食わない"]);

enum SpecialProperty: ushort
{
    NT = 0b00000000000001,
    OP = 0b00000000000010,
    CS = 0b00000000000100,
    CR = 0b00000000001000,
    PM = 0b00000000010000,
    NC = 0b00000000100000,
    NB = 0b00000001000000,
    ND = 0b00000010000000,
    CA = 0b00000100000000,
    DL = 0b00001000000000,
    TC = 0b00010000000000,
    LO = 0b00100000000000,
    AL = 0b01000000000000,
    WA = 0b10000000000000,
}

auto toStrings(ushort sps, bool detailed = true)
{
    with(SpecialProperty)
    {
        auto propMap = [
            NT: "他のプレイヤーにトレードで渡せない",
            OP: "一人一個のみ",
            CS: "売ることができない",
            CR: "修理できない",
            PM: "消耗度による威力計算を行わない",
            NC: "修理による最大耐久度低下を行わない",
            NB: "耐久度による武器の破壊が行われない",
            ND: "死亡時ドロップしない",
            CA: "カオスエイジで死亡しても消えない",
            DL: "死亡すると消える",
            TC: "タイムカプセルボックスに入れることが出来ない",
            LO: "ログアウトすると消える",
            AL: "現在のエリア限定",
            WA: "WarAgeでは性能が低下する",
            ];
        auto str(SpecialProperty p)
        {
            return detailed ? propMap[p] : p.to!string;
        }
        // return propMap.keys.filter!(p => sps&p).map!(p => propMap[p]).array;
        return propMap.keys.filter!(p => sps&p).map!(p => str(p)).array;
    }
}

auto toSpecialProperties(JSONValue[] vals)
{
    auto props = vals.map!"a.str".map!(s => s.to!SpecialProperty).array;
    return props.reduce!((a, b) => a|b).to!ushort;
}

alias ItemType = ExtendedEnum!(["UNKNOWN", "Others", "Food", "Drink", "Liquor",
                                "Medicine", "Weapon", "Armor", "Bullet", "Asset"],
                               ["不明", "その他", "食べ物", "飲み物", "酒",
                                "薬", "武器", "防具", "弾", "アセット"]);

/// 料理固有の情報
struct FoodInfo
{
    dstring name;
    real effect;
    dstring additionalEffect;
}

auto readFoods(string fname)
{
    auto res = fname.readText.parseJSON;
    enforce(res.type == JSON_TYPE.OBJECT);
    auto foods = res.object;
    return foods.keys.map!(key =>
                           tuple(key.to!dstring,
                                 key.toFoodInfo(foods[key].object)));
}

auto toFoodInfo(string s, JSONValue[string] json)
{
    FoodInfo info;
    with(info)
    {
        name = s.to!dstring;
        effect = json["効果"].jto!real;
        if (auto addition = "付加効果" in json)
        {
            additionalEffect = (*addition).jto!dstring;
        }
    }
    return info;
}

/// 飲食バフのグループ
enum AdditionalEffectGroup
{
    A, B1, B2, C1, C2, D1, D2, D3, D4, E, F, Others
}

/// 飲食バフの効果情報
struct AdditionalEffect
{
    dstring name;
    AdditionalEffectGroup group;
    int[dstring] effects;
    dstring otherEffects;
    uint duration;
    dstring remarks;
}

auto readFoodEffects(string fname)
{
    auto res = fname.readText.parseJSON;
    enforce(res.type == JSON_TYPE.OBJECT);
    auto effects = res.object;
    return effects.keys.map!(key =>
                             tuple(key.to!dstring,
                                   key.toFoodEffect(effects[key].object)));
}

auto toFoodEffect(string s, JSONValue[string] json)
{
    AdditionalEffect effect;
    with(effect)
    {
        name = s.to!dstring;
        effects = json["効果"].jto!(int[dstring]);
        if (auto others = "その他効果" in json)
        {
            otherEffects = (*others).jto!dstring;
        }
        duration = json["効果時間"].jto!uint;
        group = json["グループ"].jto!AdditionalEffectGroup;
        if (auto rem = "備考" in json)
        {
            remarks = (*rem).jto!dstring;
        }
    }
    return effect;
}

struct WeaponInfo
{
    real[Grade] damage;
    int duration;
    real range;
    real[dstring] skills;
    bool isDoubleHands;
    WeaponSlot slot;
    ShipRestriction restriction;
    Material material;
    ExhaustionType type;
    int exhaustion;
    real[dstring] effects;
    int[dstring] additionalEffect;
}

auto readWeapons(string fname)
{
    auto res = fname.readText.parseJSON;
    enforce(res.type == JSON_TYPE.OBJECT);
    auto weapons = res.object;
    return weapons.keys.map!(key =>
                             tuple(key.to!dstring,
                                   weapons[key].object.toWeaponInfo));
}

auto toWeaponInfo(JSONValue[string] json)
{
    WeaponInfo info;
    with(info)
    {
        damage = json["攻撃力"].jto!(real[Grade]);
        duration = json["攻撃間隔"].jto!int;
        range = json["射程"].jto!real;
        skills = json["必要スキル"].jto!(real[dstring]);
        slot = json["装備箇所"].jto!WeaponSlot;
        isDoubleHands = json["両手装備"].jto!bool;
        material = json["素材"].jto!Material;
        if (auto t = "消耗タイプ" in json)
        {
            type = (*t).jto!ExhaustionType;
        }
        exhaustion = json["耐久"].jto!int;
        if (auto f = "追加効果" in json)
        {
            effects = (*f).jto!(real[dstring]);
        }
        if (auto af = "付与効果" in json)
        {
            additionalEffect = (*af).jto!(int[dstring]);
        }

        if (auto rest = "シップ" in json)
        {
            restriction = (*rest).jto!ShipRestriction;
        }
        else
        {
            restriction = ShipRestriction.Any;
        }
    }
    return info;
}

struct ArmorInfo
{
    real[Grade] AC;
    real[dstring] skills;
    ArmorSlot slot;
    ShipRestriction restriction;
    Material material;
    ExhaustionType type;
    int exhaustion;
    real[dstring] effects;
    dstring additionalEffect;
}

struct BulletInfo
{
    real damage;
    real range;
    int angle;
    ShipRestriction restriction;
    real[dstring] skills;
    dstring effects;
}

auto readBullets(string fname)
{
    auto res = fname.readText.parseJSON;
    enforce(res.type == JSON_TYPE.OBJECT);
    auto bullets = res.object;
    return bullets.keys.map!(key =>
                             tuple(key.to!dstring,
                                   bullets[key].object.toBulletInfo));
}

auto toBulletInfo(JSONValue[string] json)
{
    BulletInfo info;
    with(info)
    {
        damage = json["攻撃力"].jto!real;
        range = json["射程"].jto!real;
        angle = json["角度補正角"].jto!int;
        skills = json["必要スキル"].jto!(real[dstring]);
        // if (auto f = "追加効果" in json) // 追加効果の名前を確認
        // {
        //     effects = (*f).jto!(real[dstring]);
        // }
        // if (auto af = "付与効果" in json)
        // {
        //     additionalEffect = (*af).jto!(int[dstring]);
        // }

        if (auto rest = "シップ" in json)
        {
            restriction = (*rest).jto!ShipRestriction;
        }
        else
        {
            restriction = ShipRestriction.Any;
        }
    }
    return info;
}

struct AssetInfo
{
    uint width, depth, height;
    Material material;
    int exhaustion;
}

alias ShipRestriction = ExtendedEnum!(["UNKNOWN", "Any",],
                                      ["不明", "なし",
                                       // 基本シップ
                                       // 熟練
                                       // "パンチャー", "剣士", "メイサー", "ランサー", "ガンナー", "アーチャー",
                                       // "ガーズマン", "投げ士", "レンジャー", "ブラッド サッカー", "キッカー", "ワイルドマン",
                                       // "ドリンカー", "物まね師", "テイマー", "ウィザード", "プリースト", "シャーマン", //ウィッチは？
                                       // "エンチャンター", "サモナー", "シャドウ", "魔術師", "野生児", "小悪魔",
                                       // "ベンダー", "ロックシンガー", "ソングシンガー", "スリ", "目立ちたがり", "ストリートダンサー",
                                       // // 基本
                                       // "フォールマン", "スイマー", "デッドマン", "ヘルパー", "休憩人", "マイナー",
                                       // "木こり", "耕作師", "釣り人", "解読者",
                                       // // 生産
                                       // "料理師", "鍛冶師", "バーテンダー", "木工師", "仕立て屋", "調合師",
                                       // "細工師", "筆記師", "調髪師", "栽培師",
                                       // // 複合
                                       // "ウォーリアー", "アルケミスト", "フォレスター", "ネクロマンサー", "クリエイター",
                                       // "爆弾男", "ブリーダー", "テンプルナイト", "ドルイド", "紺碧の賢者", // 爆弾女は？
                                       // "グレート クリエイター", "傭兵", "サムライ", "マイン ビショップ", "厨房師",
                                       // "アサシン", "海戦士", "ブレイブナイト", "イビルナイト", "コスプレイヤー",
                                       // "物好き", "アスリート", "酔拳士", "荒くれ者", "新人アイドル",
                                       // "ハウスキーパー", "アドベンチャラー", "スパイ", "レディース", "アカデミアン", // チンピラは？
                                       // "ブラッドバード", "デュエリスト", "コレクター"
                                          ]);

alias WeaponSlot = ExtendedEnum!(["UNKNOWN", "Right", "Left", "Both"],
                                 ["不明", "右手", "左手", "左右"]);

alias ArmorSlot = ExtendedEnum!(["UNKNOWN",
                                 "HeadProtector", "BodyProtector", "HandProtector",
                                 "PantsProtector", "ShoesProtector", "ShoulderProtector", "WaistProtector",
                                 "HeadOrnament", "FaceOrnament", "EarOrnament",
                                 "FingerOrnament", "BreastOrnament", "BackOrnament", "WaistOrnament"],
                                ["不明",
                                 "頭(防)", "胴(防)", "手(防)",
                                 "パンツ(防)", "靴(防)", "肩(防)", "腰(防)",
                                 "頭(装)", "顔(装)", "耳(装)",
                                 "指(装)", "胸(装)", "背中(装)", "腰(装)"]);

alias Material = ExtendedEnum!(["UNKNOWN",
                                "Copper", "Bronze", "Iron", "Steel", "Silver", "Gold", "Mithril", "Orichalcum",
                                "Cotton", "Silk", "AnimalSkin", "DragonSkin", "Plant", "Wood", "Treant",
                                "Paper", "Bamboo", "BlackBamboo", "Bone", "Stone", "Glass", "Crystal", "Cobalt", "Chaos"],
                               ["不明",
                                "銅", "青銅", "鉄", "鋼鉄", "銀", "金", "ミスリル", "オリハルコン",
                                "綿", "絹", "動物の皮", "竜の皮", "プラント", "木", "トレント",
                                "紙", "竹筒", "黒い竹", "骨", "石", "ガラス", "クリスタル", "コバルト", "カオス"]);

alias Grade = ExtendedEnum!(["UNKNOWN", "Degraded", "NG", "HG", "MG"],
                            ["不明", "劣化", "NG", "HG", "MG"]);

alias ExhaustionType = ExtendedEnum!(["UNKNOWN", "Points", "Times"],
                                     ["不明", "耐久値", "使用可能回数"]);

/// 薬と包帯固有の情報
struct MedicineInfo
{
    real[dstring] skill;
    dstring effect;
}

auto readMedicines(string fname)
{
    auto res = fname.readText.parseJSON;
    enforce(res.type == JSON_TYPE.OBJECT);
    auto medicines = res.object;
    return medicines.keys.map!(key =>
                             tuple(key.to!dstring,
                                   medicines[key].object.toMedicineInfo));
}

auto toMedicineInfo(JSONValue[string] json)
{
    MedicineInfo info;
    with(info)
    {
        effect = json["効果"].jto!dstring;
        if (auto f = "必要スキル" in json)
        {
            skill = (*f).jto!(real[dstring]);
        }
    }
    return info;
}

struct Overlaid(T)
{
    this(T orig, T* ol)
    {
        original = orig;
        overlaid = ol;
    }

    @property auto ref opDispatch(string field)()
        if (hasMember!(T, field))
    {
        if (isOverlaid!field)
        {
            return mixin("overlaid."~field);
        }
        else
        {
            return mixin("original."~field);
        }
    }

    @property auto isOverlaid(string field)()
        if (hasMember!(T, field))
    {
        return overlaid !is null && !isValidValue(mixin("original."~field));
    }
private:
    static auto isValidValue(T)(T val)
    {
        static if (isFloatingPoint!T)
            return !val.isNaN;
        else static if (isSomeString!T)
            return !val.empty;
        else static if (isIntegral!T)
            return val > 0;
        else static if (is(T == bool))
            return val;
        else static if (is(T == real[PetFoodType]))
        {
            return val.keys[0] != PetFoodType.UNKNOWN;
        }
        else
            return val != T.init;
    }

    T original;
    T* overlaid;
}

unittest
{
    Item orig;
    with(orig)
    {
        name = "テスト";
        ename = "test";
        weight = 0.3;
        price = 100;
        info = "Info";
        petFoodInfo[PetFoodType.UNKNOWN.to!PetFoodType] = 0;
    }

    auto overlaid = Overlaid!Item(orig, null);
    foreach(field; FieldNameTuple!Item)
    {
        assert(!overlaid.isOverlaid!field);
    }
    assert(overlaid.name == "テスト");
}

unittest
{
    Item orig;
    orig.name = "テスト";

    Item item;
    item.name = "テスト";
    item.ename = "test";
    item.weight = 1.4;

    auto overlaid = Overlaid!Item(orig, &item);
    assert(!overlaid.isOverlaid!"name");
    assert(overlaid.name == "テスト");

    assert(overlaid.isOverlaid!"ename");
    assert(overlaid.ename == "test");

    assert(overlaid.isOverlaid!"weight");
    assert(overlaid.weight == 1.4);

    assert(overlaid.isOverlaid!"price");
    assert(overlaid.price == 0);
}
