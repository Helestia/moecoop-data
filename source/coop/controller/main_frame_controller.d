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
module coop.controller.main_frame_controller;

import coop.view.main_frame;
import coop.model.config;
import coop.model.character;
import coop.model.wisdom;
import coop.migemo;

import std.file;
import std.path;
import std.exception;

class MainFrameController
{
    this(MainFrame frame, Wisdom wisdom, Character[dstring] chars, Config config, Wisdom customWisdom)
    {
        frame_ = frame;
        wisdom_ = wisdom;
        chars_ = chars;
        config_ = config;
        cWisdom_ = customWisdom;

        loadMigemo;
    }

    @property auto frame() { return frame_; }
    @property auto config() { return config_; }
    @property auto characters() { return chars_; }
    @property auto wisdom() { return wisdom_; }
    @property auto cWisdom() { return cWisdom_; }
    @property auto migemo() { return migemo_; }

    auto loadMigemo()
    {
        if (config.migemoDLL.exists && config.migemoDict.exists)
        {
            try{
                migemo_ = new Migemo(config_.migemoDLL, config_.migemoDict);
                migemo_.load(buildPath("resource", "dict", "moe-dict"));
                enforce(migemo_.isEnable);
                frame_.enableMigemo;
            } catch(MigemoException e) {
                migemo_ = null;
                frame_.disableMigemo;
            }
        }
    }

    Config config_;
    Character[dstring] chars_;
    Wisdom wisdom_, cWisdom_;
    Migemo migemo_;
    MainFrame frame_;
}

mixin template TabController()
{
public:
    import std.format;
    mixin(format("alias FrameType = %s;", typeof(this).stringof[0..$-10]));

    FrameType frame() { return frame_; }

    @property auto config()
    {
        return frame_.root.controller.config;
    }

    @property auto characters()
    {
        return frame_.root.controller.characters;
    }

    @property auto wisdom()
    out(ret)
    {
        assert(ret);
    } body {
        return frame_.root.controller.wisdom;
    }

    @property auto cWisdom()
    out(ret)
    {
        assert(ret);
    } body {
        return frame_.root.controller.cWisdom;
    }

    @property auto migemo()
    {
        return frame_.root.controller.migemo;
    }
protected:
    FrameType frame_;
}
