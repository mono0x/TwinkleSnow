# -*- coding: utf-8 -*-

require 'tokyotyrant'

def tokyo_tyrant(host, port)
  db = TokyoTyrant::RDBTBL.new
  db.open host, port
  db.setindex 'tab_id', TokyoTyrant::RDBTBL::ITDECIMAL
  db
end

#DB.put id, { 'tab_id' => tab_id, 'data' => data }

