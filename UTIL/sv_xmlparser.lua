-- from https://github.com/jonathanpoelen/xmlparser
--[[
MIT License

Copyright (c) 2016 Jonathan Poelen

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local io, string, pairs = io, string, pairs

-- http://lua-users.org/wiki/StringTrim
local trim = function(s)
  local from = s:match"^%s*()"
  return from > #s and "" or s:match(".*%S", from)
end

local slashchar = string.byte('/', 1)
local E = string.byte('E', 1)

function parse(s)
  -- remove comments
  s = s:gsub('<!%-%-(.-)%-%->', '')

  local t, l = {}, {}

  local addtext = function(txt)
    txt = txt:match'^%s*(.*%S)' or ''
    if #txt ~= 0 then
      t[#t+1] = {text=txt}
    end    
  end
  
  s:gsub('<([?!/]?)([-:_%w]+)%s*(/?>?)([^<]*)', function(type, name, closed, txt)
    -- open
    if #type == 0 then
      local attrs, orderedattrs = {}, {}
      if #closed == 0 then
        local len = 0
        for all,aname,_,value,starttxt in string.gmatch(txt, "(.-([-_%w]+)%s*=%s*(.)(.-)%3%s*(/?>?))") do
          len = len + #all
          attrs[aname] = value
          if #starttxt ~= 0 then
            txt = txt:sub(len+1)
            closed = starttxt
            break
          end
        end
      end
	  
	  local count = 0
	  for i, v in pairs(attrs) do
		count = count+1
	  end
	  
	  if count > 0 then
		t[#t+1] = {tag=name}
		local attrstable = { }
		for i,v in pairs(attrs) do
			attrstable[i] = v
		end
		t[#t][name] = attrstable
	  else
		t[#t+1] = {tag=name}  
		t[#t][name] = { }
	  end

      if closed:byte(1) ~= slashchar then
        l[#l+1] = t
		t = t[#t][name]
      end

      addtext(txt)
    -- close
    elseif '/' == type then
      t = l[#l]
      l[#l] = nil

      addtext(txt)
	  end
  end)

  return t
end

function parseFile(data)
  return data and parse(data)
end

function defaultEntityTable()
  return { quot='"', apos='\'', lt='<', gt='>', amp='&', tab='\t', nbsp=' ', }
end

function replaceEntities(s, entities)
  return s:gsub('&([^;]+);', entities)
end

function createEntityTable(docEntities, resultEntities)
  entities = resultEntities or defaultEntityTable()
  for _,e in pairs(docEntities) do
    e.value = replaceEntities(e.value, entities)
    entities[e.name] = e.value
  end
  return entities
end

