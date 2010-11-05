# -*- coding: utf-8 -*-

require 'sequel'

DB = Sequel.sqlite('data/tweets.db')

DB.create_table? :tweets do
  primary_key :id
  column :tab_id, :integer
  column :data, :text
  column :html, :text
  index :tab_id
end

class TweetStorage

  def initialize
  end

  def append(tab_id, data, html)
    DB[:tweets].insert :id => data['id'], :tab_id => tab_id, :data => data.to_json, :html => html
  end

  def unread
    DB[:tweets].order_by(:id).map {|r|
      {
        'tab_id' => r[:tab_id],
        'data' => JSON.parse(r[:data]),
        'html' => r[:html],
      }
    }
  end

  def delete(tab_id, since_id)
    DB[:tweets].filter(:tab_id => tab_id).filter('id <= ?', since_id).delete
  end

end

