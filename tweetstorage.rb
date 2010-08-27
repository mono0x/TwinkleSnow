# -*- coding: utf-8 -*-

require 'tokyotyrant'

class TweetStorage

  def initialize(host, port)
    @db = TokyoTyrant::RDBTBL.new
    @db.open host, port
    @db.setindex 'tab_id', TokyoTyrant::RDBTBL::ITDECIMAL
  end

  def append(tab_id, data, html)
    @db.put data['id'], { 'tab_id' => tab_id, 'data' => data.to_json, 'html' => html, }
  end

  def unread
    q = TokyoTyrant::RDBQRY.new(@db)
    q.setorder '', TokyoTyrant::RDBQRY::QONUMASC
    q.search.map {|key|
      value = @db.get(key)
      {
        'tab_id' => value['tab_id'],
        'data' => JSON.parse(value['data']),
        'html' => value['html'],
      }
    }
  end

  def delete(tab_id, since_id)
    q = TokyoTyrant::RDBQRY.new(@db)
    q.addcond 'tab_id', TokyoTyrant::RDBQRY::QCNUMEQ, tab_id.to_s
    q.addcond '', TokyoTyrant::RDBQRY::QCNUMLE, since_id.to_s
    q.search.each do |key|
      @db.delete key
    end
  end

end

