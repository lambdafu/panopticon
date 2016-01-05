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
use qmlrs::variant::FromQVariant;
use panopticon::layer::Layer;
use panopticon::region::Region;
use panopticon::mnemonic::Bound;
use std::ops::Range;
use std::iter;

use graph_algos::GraphTrait;

pub struct LinearData {
    pub name: String,
    pub count: i64,
    pub lines: Vec<String>
}

fn fill_from_layer(data: &mut LinearData, region: &Region, bound: &Bound, layer: &Layer) {
    let mut prev_line: String = "".to_string();
    let mut skipping: bool = false;

    let mut line: String = "".to_string();
    let mut prepend = bound.start - (bound.start & !0x7);
    if prepend > 0 {
        line = iter::repeat(" ").take(2 + (prepend as usize - 1) * 3).collect();
    }

    for (offset, cell) in region.iter().cut(&(bound.start..bound.end)).enumerate() {
        let addr = bound.start + offset as u64;
	let elem = if let Some(byte) = cell {
            format!("{:02x}", byte)
        }
        else {
            format!("--")
        };

        if (addr % 8 == 0) {
            line = format!("{}", elem);
        } else {
            line = format!("{} {}", line.clone(), elem);
        }

        if (addr + 1) % 8 == 0 {
            if skipping {
		if prev_line == line {
                    continue;
                } else {
                    skipping = false;
                }
            }
            if prev_line == line {
                data.lines.push("*".to_string());
                skipping = true;
            } else {
                data.lines.push(format!("{:04x} {}", addr & !0x7, line.clone()));
	        prev_line = line.clone();
	    }
	}
        else if addr == bound.end {
            data.lines.push(format!("{:04x} {}", addr & !0x7, line.clone()));
        }
    }
}

fn fill_data(data: &mut LinearData)
{
    let read_guard_ = PROJECT.read().unwrap();
    let proj: &Project = read_guard_.as_ref().unwrap();
    let mut last_address: Option<u64> = None;

    for (bound, regionref) in proj.sources.projection() {
        let region = proj.sources.dependencies.vertex_label(regionref).unwrap();
        data.lines.push(format!("Region name={}, size={}", region.name(), region.size()).clone());
        for (bound, layer) in region.flatten() {
            let line = match layer {
                &Layer::Opaque(_) => format!("OpaqueLayer start={}, end={}", bound.start, bound.end).clone(),
                &Layer::Sparse(_) => format!("SparseLayer start={}, end={}", bound.start, bound.end).clone()
	    };
            data.lines.push(line);
            fill_from_layer(data, &region, &bound, &layer);
            last_address = Some(bound.end); 
        }
    }
    if let Some(addr) = last_address {
        data.lines.push(format!("{:04x}", addr));
    }
}


fn ensure_data() {
    {
        let read_guard = LINEARDATA.read().unwrap();
        let data: Option<&LinearData> = read_guard.as_ref();
	if let Some(lindata) = data {
	    return;
	}
    }

    let mut data = LinearData {
    	name: "Test".to_string(),
        count: 3,
	lines: vec![]
    };

    fill_data(&mut data);

    *LINEARDATA.write().unwrap() = Some(data);
}

pub fn row_info(arg0: &Variant) -> Variant {
    let line = if let &Variant::I64(val) = arg0 {
      val
    } else {
      panic!("Something went terribly wrong!");
    };

    let read_guard_ = PROJECT.read().unwrap();
    let proj: &Project = read_guard_.as_ref().unwrap();

    ensure_data();
    let read_guard = LINEARDATA.read().unwrap();
    let data = read_guard.as_ref().unwrap();

    Variant::String(data.lines[line as usize].clone())
}

pub fn row_count() -> Variant {
    let read_guard_ = PROJECT.read().unwrap();
    let proj: &Project = read_guard_.as_ref().unwrap();

    ensure_data();
    let read_guard = LINEARDATA.read().unwrap();
    let data = read_guard.as_ref().unwrap();

    Variant::I64(data.lines.len() as i64)
}

