# -*- coding: utf-8 -*-

class ConfigLoader

  class << self

    def load(src)
      c = new
      c.instance_eval src
      c.tabs.each_index do |i|
        c.tabs[i][:id] = i
      end
      c
    end

    def load_file(path)
      load open(path).read
    end
   
  end

  attr_reader :account
  attr_reader :password
  attr_reader :web_socket
  attr_reader :tokyo_tyrant
  attr_reader :im_kayac
  attr_reader :tabs
  attr_reader :block
  attr_reader :oauth

end


