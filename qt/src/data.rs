/*
 * Panopticon - A libre disassembler
 * Copyright (C) 2015  Panopticon authors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

use qmlrs::{Variant};
use panopticon::project::Project;
use controller::{PROJECT,LINEARDATA};

pub struct LinearData {
    pub name: String,
    pub count: i64
}

pub fn ensure_data() -> &'static LinearData {
    {
        let read_guard = LINEARDATA.read().unwrap();
        let data: Option<&LinearData> = read_guard.as_ref();
	if &data == None {
	}
	else {
	   return data.unwrap();
	}
    }

    {
	let mut data = LinearData {
            name: "Test".to_string(),
            count: 3
        };
        LINEARDATA.write().unwrap() = Some(data);
    }
    ensure_data();
}

pub fn row_info(arg0: &Variant) -> Variant {
    let read_guard = PROJECT.read().unwrap();
    let proj: &Project = read_guard.as_ref().unwrap();

    Variant::String(proj.name.clone())
}

pub fn row_count() -> Variant {
    let read_guard = PROJECT.read().unwrap();
    let proj: &Project = read_guard.as_ref().unwrap();


    Variant::I64(3)
}
