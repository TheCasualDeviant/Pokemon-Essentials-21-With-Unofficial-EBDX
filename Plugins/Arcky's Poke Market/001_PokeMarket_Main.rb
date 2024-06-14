class PokemonMartAdapter
  def setMoney(value)
    money = $player.money - value
    times =  money.abs > 50 ? 50 : money.abs 
    amount = money != 0 ? (money / times).round : 0
    $amount = (1..times).map { |step| $player.money - (amount * step) }
  end

  def getPrice(item, selling = false, discount = nil)
    if selling.is_a?(Numeric)
      discount = selling if selling
      selling = false 
    end 
    var = $game_variables[discount.abs] if discount
    if discount && !var.nil? && var > 0
      discItem = []
      APMSettings::DISCOUNTS.each do |item, var|
        if !item.is_a?(Numeric) && !(item.is_a?(Symbol) && GameData::Item.exists?(item))
          Console.echoln_li _INTL("#{item} is not defined in the Items.txt PBS file.")
          next 
        elsif item.is_a?(Numeric)
          discItem = var if item == discount
        else
          array = var.find { |varr| varr[0] == discount }
          discItem = array[1] if array
        end
        break if !discItem.empty?
      end 
      if discItem.empty? && var != 0
        disc = discount < 0 ? var * -1 : var
      else 
        disc = discItem[var] || 0
      end
    else 
      disc = 0
    end
    price = GameData::Item.get(item).price.to_f
    newPrice = (price * ((100 - disc).to_f / 100)).round(0)
    if $game_temp.mart_prices && $game_temp.mart_prices[item]
      if selling
        return $game_temp.mart_prices[item][1] if $game_temp.mart_prices[item][1] >= 0
      elsif $game_temp.mart_prices[item][0] > 0
        return $game_temp.mart_prices[item][0]
      end
    end
    return GameData::Item.get(item).sell_price if selling
    return newPrice #GameData::Item.get(item).price
  end

  def getDisplayPrice(item, selling = false, discount = nil)
    price = getPrice(item, selling, discount).to_s_formatted
    return _INTL("$ {1}", price)
  end
end 

class BuyAdapter
  def getDisplayPrice(item, discount)
    @adapter.getDisplayPrice(item, false, discount)
  end
end 

class PokemonMart_Scene
  def pbRefresh
    if @subscene
      @subscene.pbRefresh
    else
      itemwindow = @sprites["itemwindow"]
      @sprites["icon"].item = itemwindow.item
      @sprites["itemtextwindow"].text =
        (itemwindow.item) ? @adapter.getDescription(itemwindow.item) : _INTL("Quit shopping.")
      @sprites["qtywindow"].visible = !itemwindow.item.nil?
      @sprites["qtywindow"].text    = _INTL("In Bag:<r>{1}", @adapter.getQuantity(itemwindow.item))
      @sprites["qtywindow"].y       = Graphics.height - 102 - @sprites["qtywindow"].height
      itemwindow.refresh
    end
    if $amount && !$amount.empty?
      $amount.each do |money|
        $player.money = money
        @sprites["moneywindow"].text = _INTL("Money:\n<r>{1}", @adapter.getMoneyString)
        if Essentials::VERSION.include?("21")
          pbWait(0.01)
        else 
          pbWait(1)
        end 
      end 
      $amount = []
    else 
      @sprites["moneywindow"].text = _INTL("Money:\n<r>{1}", @adapter.getMoneyString)
    end
  end

  def pbStartBuyOrSellScene(buying, stock, choiceStock, stockByCat, adapter, pokeMartTracker, discount)
    # Scroll right before showing screen
    pbScrollMap(6, 5, 5)
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    if choiceStock.nil?
      @stock = stock
      @stockIndex = 0
    else 
      @stock = stock = choiceStock
      @stockIndex = stockByCat.values.index(choiceStock)
      @stockByCat = stockByCat
      @catName = stockByCat.keys[@stockIndex]
    end
    @pokeMartTracker = pokeMartTracker
    @discount = discount
    @adapter = adapter
    @sprites = {}
    @sprites["background"] = IconSprite.new(0, 0, @viewport)
    if Essentials::VERSION.include?("21")
      @sprites["background"].setBitmap("Graphics/UI/Mart/bg")
    else 
      @sprites["background"].setBitmap("Graphics/Pictures/martScreen")
    end 
    @sprites["icon"] = ItemIconSprite.new(36, Graphics.height - 50, nil, @viewport)
    @winAdapter = buying ? BuyAdapter.new(adapter) : SellAdapter.new(adapter)
    @sprites["category"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["category"].visible = true 
    pbSetSystemFont(@sprites["category"].bitmap)
    if !@catName.nil?
      pbDrawTextPositions(@sprites["category"].bitmap, [
        [@catName, Graphics.width - 300, 30, 0, Color.new(88, 88, 80), Color.new(168, 184, 184)],
        ["Page #{@stockIndex + 1}/#{@stockByCat.length}", 490, 30, 1, Color.new(88, 88, 80), Color.new(168, 184, 184)],
        ["-----------------------", Graphics.width - 300, 46, 0, Color.new(88, 88, 80), Color.new(168, 184, 184)]
      ])
      yMin = 42
      yMax = 156
    else 
      yMin = 10
      yMax = 128
    end 
    @sprites["itemwindow"] = Window_PokemonMart.new(
      stock, @winAdapter, Graphics.width - 316 - 16, yMin, 330 + 16, Graphics.height - yMax, nil, @pokeMartTracker, @discount
    )
    @sprites["itemwindow"].viewport = @viewport
    @sprites["itemwindow"].index = 0
    @sprites["itemwindow"].refresh
    @sprites["itemtextwindow"] = Window_UnformattedTextPokemon.newWithSize(
      "", 64, Graphics.height - 96 - 16, Graphics.width - 64, 128, @viewport
    )
    pbPrepareWindow(@sprites["itemtextwindow"])
    @sprites["itemtextwindow"].baseColor = Color.new(248, 248, 248)
    @sprites["itemtextwindow"].shadowColor = Color.black
    @sprites["itemtextwindow"].windowskin = nil
    @sprites["helpwindow"] = Window_AdvancedTextPokemon.new("")
    pbPrepareWindow(@sprites["helpwindow"])
    @sprites["helpwindow"].visible = false
    @sprites["helpwindow"].viewport = @viewport
    pbBottomLeftLines(@sprites["helpwindow"], 1)
    @sprites["moneywindow"] = Window_AdvancedTextPokemon.new("")
    pbPrepareWindow(@sprites["moneywindow"])
    @sprites["moneywindow"].setSkin("Graphics/Windowskins/goldskin")
    @sprites["moneywindow"].visible = true
    @sprites["moneywindow"].viewport = @viewport
    @sprites["moneywindow"].x = 0
    @sprites["moneywindow"].y = 0
    @sprites["moneywindow"].width = 190
    @sprites["moneywindow"].height = 96
    @sprites["moneywindow"].baseColor = Color.new(88, 88, 80)
    @sprites["moneywindow"].shadowColor = Color.new(168, 184, 184)
    @sprites["qtywindow"] = Window_AdvancedTextPokemon.new("")
    pbPrepareWindow(@sprites["qtywindow"])
    @sprites["qtywindow"].setSkin("Graphics/Windowskins/goldskin")
    @sprites["qtywindow"].viewport = @viewport
    @sprites["qtywindow"].width = 190
    @sprites["qtywindow"].height = 64
    @sprites["qtywindow"].baseColor = Color.new(88, 88, 80)
    @sprites["qtywindow"].shadowColor = Color.new(168, 184, 184)
    @sprites["qtywindow"].text = _INTL("In Bag:<r>{1}", @adapter.getQuantity(@sprites["itemwindow"].item))
    @sprites["qtywindow"].y    = Graphics.height - 102 - @sprites["qtywindow"].height
    pbDeactivateWindows(@sprites)
    @buying = buying
    pbRefresh
    Graphics.frame_reset
  end

  def pbStartBuyScene(stock, choiceStock, stockByCat, adapter, pokeMartTracker, discount)
    pbStartBuyOrSellScene(true, stock, choiceStock, stockByCat, adapter, pokeMartTracker, discount)
  end

  def pbChooseBuyItem
    itemwindow = @sprites["itemwindow"]
    @sprites["helpwindow"].visible = false
    pbActivateWindow(@sprites, "itemwindow") do
      pbRefresh
      loop do
        Graphics.update
        Input.update
        olditem = itemwindow.item
        self.update
        pbRefresh if itemwindow.item != olditem
        if Input.trigger?(Input::LEFT) && !@stockByCat.nil?
          @stockIndex -= 1
          @stockIndex = @stockByCat.length - 1 if @stockIndex < 0
          updateStock
          itemwindow = @sprites["itemwindow"]
          pbRefresh
          next
        elsif Input.trigger?(Input::RIGHT) && !@stockByCat.nil?
          @stockIndex += 1
          @stockIndex = 0 if @stockIndex > @stockByCat.length - 1
          updateStock
          itemwindow = @sprites["itemwindow"]
          pbRefresh
          next
        elsif Input.trigger?(Input::BACK)
          pbPlayCloseMenuSE
          return nil
        elsif Input.trigger?(Input::USE)
          if itemwindow.index < @stock.length
            pbRefresh
            return @stock[itemwindow.index]
          else
            return nil
          end
        end
      end
    end
  end

  def updateStock
    @stock = @stockByCat.values[@stockIndex]
    if @sprites["category"]
      @sprites["category"].bitmap.clear
      @catName = @stockByCat.keys[@stockIndex]
      pbDrawTextPositions(@sprites["category"].bitmap, [
        [@catName, Graphics.width - 300, 30, 0, Color.new(88, 88, 80), Color.new(168, 184, 184)],
        ["Page #{@stockIndex + 1}/#{@stockByCat.length}", 490, 30, 1, Color.new(88, 88, 80), Color.new(168, 184, 184)],
        ["-----------------------", Graphics.width - 300, 46, 0, Color.new(88, 88, 80), Color.new(168, 184, 184)]
      ])
      yMin = 42
      yMax = 156
    else 
      yMin = 10
      yMax = 124
    end 
    @sprites["itemwindow"].dispose
    @sprites["itemwindow"] = Window_PokemonMart.new(
      @stock, @winAdapter, Graphics.width - 316 - 16, yMin, 330 + 16, Graphics.height - yMax, nil, @pokeMartTracker, @discount
    )
    @sprites["itemwindow"].viewport = @viewport
    @sprites["itemwindow"].index = 0
    @sprites["itemwindow"].refresh
  end 

  def pbChooseNumber(helptext, item, maximum)
    curnumber = 1
    ret = 0
    helpwindow = @sprites["helpwindow"]
    itemprice = @adapter.getPrice(item, !@buying, @discount)
    pbDisplay(helptext, true)
    using(numwindow = Window_AdvancedTextPokemon.new("")) do   # Showing number of items
      pbPrepareWindow(numwindow)
      numwindow.viewport = @viewport
      numwindow.width = 224
      numwindow.height = 64
      numwindow.baseColor = Color.new(88, 88, 80)
      numwindow.shadowColor = Color.new(168, 184, 184)
      numwindow.text = _INTL("x{1}<r>$ {2}", curnumber, (curnumber * itemprice).to_s_formatted)
      pbBottomRight(numwindow)
      numwindow.y -= helpwindow.height
      loop do
        Graphics.update
        Input.update
        numwindow.update
        update
        oldnumber = curnumber
        if Input.repeat?(Input::LEFT)
          curnumber -= 10
          curnumber = 1 if curnumber < 1
          if curnumber != oldnumber
            numwindow.text = _INTL("x{1}<r>$ {2}", curnumber, (curnumber * itemprice).to_s_formatted)
            pbPlayCursorSE
          end
        elsif Input.repeat?(Input::RIGHT)
          curnumber += 10
          curnumber = maximum if curnumber > maximum
          if curnumber != oldnumber
            numwindow.text = _INTL("x{1}<r>$ {2}", curnumber, (curnumber * itemprice).to_s_formatted)
            pbPlayCursorSE
          end
        elsif Input.repeat?(Input::UP)
          curnumber += 1
          curnumber = 1 if curnumber > maximum
          if curnumber != oldnumber
            numwindow.text = _INTL("x{1}<r>$ {2}", curnumber, (curnumber * itemprice).to_s_formatted)
            pbPlayCursorSE
          end
        elsif Input.repeat?(Input::DOWN)
          curnumber -= 1
          curnumber = maximum if curnumber < 1
          if curnumber != oldnumber
            numwindow.text = _INTL("x{1}<r>$ {2}", curnumber, (curnumber * itemprice).to_s_formatted)
            pbPlayCursorSE
          end
        elsif Input.trigger?(Input::USE)
          ret = curnumber
          break
        elsif Input.trigger?(Input::BACK)
          pbPlayCancelSE
          ret = 0
          break
        end
      end
    end
    helpwindow.visible = false
    return ret
  end
end

class PokemonMartScreen
  def initialize(scene, stock, speech = nil, choiceStock = nil, stockByCat = nil, pokeMartTracker = nil, discount = nil)
    @scene = scene
    @stock = stock
    @discount = discount
    unless speech.nil?
      @getSpeech = APMSettings.const_get(speech.gsub(" ", "")) if APMSettings.const_defined?(speech.gsub(" ", ""))
    else
      @getSpeech = {}
    end
    @choiceStock = choiceStock
    @stockByCat = stockByCat
    $pokeMartTracker = pokeMartTracker
    @adapter = PokemonMartAdapter.new
  end

  def pbBuyScreen
    @scene.pbStartBuyScene(@stock, @choiceStock, @stockByCat, @adapter, $pokeMartTracker, @discount)
    item = nil
    loop do
      item = @scene.pbChooseBuyItem
      break if !item
      quantity       = 0
      itemname       = @adapter.getDisplayName(item)
      itemnameplural = @adapter.getDisplayNamePlural(item)
      price = @adapter.getPrice(item, @discount)
      if @adapter.getMoney < price
        pbDisplayPaused(_INTL(@getSpeech[:NotEnoughMoney]&.sample || "You don't have enough money."))
        next
      end
      if GameData::Item.get(item).is_important?
        next if !pbConfirm(_INTL(@getSpeech[:BuyItemImportant]&.sample || "So you want {1}?\nIt'll be ${2}. All right?", itemname, price.to_s_formatted))
        quantity = 1
      else
        maxafford = (price <= 0) ? Settings::BAG_MAX_PER_SLOT : @adapter.getMoney / price
        maxafford = Settings::BAG_MAX_PER_SLOT if maxafford > Settings::BAG_MAX_PER_SLOT
        entry = $pokeMartTracker[:items].find { |entry| entry[:name] == item } unless $pokeMartTracker.nil?
        maxafford = entry[:limit] if !entry.nil? && entry[:limit] < maxafford && entry[:limit] <= Settings::BAG_MAX_PER_SLOT
        if !@discount.nil? && $game_variables[@discount] > 0
          oldPrice = @adapter.getPrice(item, nil)
          if price != oldPrice
            if price < oldPrice
              quantity = @scene.pbChooseNumber(
                _INTL(@getSpeech[:BuyItemAmountDiscount]&.sample || "So how many {1}?", itemnameplural, price, oldPrice), 
                item, maxafford) unless maxafford == 0
            elsif price > oldPrice
              quantity = @scene.pbChooseNumber(
                _INTL(@getSpeech[:BuyItemAmountOvercharge]&.sample || "So how many {1}?", itemnameplural, price, oldPrice), 
                item, maxafford) unless maxafford == 0
            end 
          else
            Console.echoln_li _INTL("Please check the value of game variable #{@discount}, it's too high according to it's DISCOUNTS values")
          end 
        else 
          quantity = @scene.pbChooseNumber(
            _INTL(@getSpeech[:BuyItemAmount]&.sample || "So how many {1}?", itemnameplural), 
            item, maxafford) unless maxafford == 0
        end 
        if !entry.nil? && entry[:limit] == 0
          quantity = 0
          pbDisplayPaused(_INTL(@getSpeech[:BuyOutOfStock]&.sample || "I'm sorry, we are currently out of {1}. Come back {2}.", itemnameplural, $pokeMartTracker[:refresh]))
        end 
        next if quantity == 0
        price *= quantity
        if quantity > 1
          next if !pbConfirm(_INTL(@getSpeech[:BuyItemMult]&.sample || "So you want {1} {2}?\nThey'll be ${3}. All right?", quantity, itemnameplural, price.to_s_formatted))
        elsif quantity > 0
          next if !pbConfirm(_INTL(@getSpeech[:BuyItem]&.sample || "So you want {1} {2}?\nIt'll be ${3}. All right?", quantity, itemname, price.to_s_formatted))
        end
      end
      if @adapter.getMoney < price
        pbDisplayPaused(_INTL(@getSpeech[:NotEnoughMoney]&.sample || "You don't have enough money."))
        next
      end
      entry[:limit] -= quantity if !entry.nil? && quantity != 0
      added = 0
      quantity.times do
        break if !@adapter.addItem(item)
        added += 1
      end
      if added == quantity
        $stats.money_spent_at_marts += price
        $stats.mart_items_bought += quantity
        @adapter.setMoney(@adapter.getMoney - price)
        @stock.delete_if { |item| GameData::Item.get(item).is_important? && $bag.has?(item) }
        if !@stockByCat.nil?
          @stockByCat.each do |key, values|
            values.delete_if do |item|
              GameData::Item.get(item).is_important? && $bag.has?(item)
            end
            if values.empty?
              @stockByCat.delete(key)
            end 
          end
        end 
        pbDisplayPaused(_INTL(@getSpeech[:BuyThanks]&.sample || "Here you are! Thank you!")) { pbSEPlay("Mart buy item") }
        Achievements.setProgress("ITEMS_BOUGHT",$stats.mart_items_bought) if PluginManager.installed?("Mega MewThree's Achievement System")
        if quantity >= 10 && GameData::Item.exists?(:PREMIERBALL)
          if Settings::MORE_BONUS_PREMIER_BALLS && GameData::Item.get(item).is_poke_ball?
            premier_balls_added = 0
            (quantity / 10).times do
              break if !@adapter.addItem(:PREMIERBALL)
              premier_balls_added += 1
            end
            ball_name = GameData::Item.get(:PREMIERBALL).name
            ball_name = GameData::Item.get(:PREMIERBALL).name_plural if premier_balls_added > 1
            $stats.premier_balls_earned += premier_balls_added
            pbDisplayPaused(_INTL(@getSpeech[:BuyBonusMult]&.sample || "And have {1} {2} on the house!", premier_balls_added, ball_name))
          elsif !Settings::MORE_BONUS_PREMIER_BALLS && GameData::Item.get(item) == :POKEBALL
            if @adapter.addItem(:PREMIERBALL)
              ball_name = GameData::Item.get(:PREMIERBALL).name
              $stats.premier_balls_earned += 1
              pbDisplayPaused(_INTL(@getSpeech[:BuyBonus]&.sample || "And have 1 {1} on the house!", ball_name))
            end
          end
        end
      else
        added.times do
          if !@adapter.removeItem(item)
            raise _INTL("Failed to delete stored items")
          end
        end
        pbDisplayPaused(_INTL(@getSpeech[:NoRoomInBag]&.sample || "You have no room in your Bag."))
      end
    end
    @scene.pbEndBuyScene
  end

  def pbSellScreen
    item = @scene.pbStartSellScene(@adapter.getInventory, @adapter)
    loop do
      item = @scene.pbChooseSellItem
      break if !item
      itemname       = @adapter.getDisplayName(item)
      itemnameplural = @adapter.getDisplayNamePlural(item)
      if !@adapter.canSell?(item)
        pbDisplayPaused(_INTL(@getSpeech[:CantSellItem]&.sample || "Oh, no. I can't buy {1}.", itemnameplural))
        next
      end
      price = @adapter.getPrice(item, true, @discount)
      qty = @adapter.getQuantity(item)
      next if qty == 0
      @scene.pbShowMoney
      if qty > 1
        qty = @scene.pbChooseNumber(
          _INTL(@getSpeech[:SellItemAmount]&.sample || "How many {1} would you like to sell?", itemnameplural), item, qty, @discount
        )
      end
      if qty == 0
        @scene.pbHideMoney
        next
      end
      price *= qty
      if pbConfirm(_INTL(@getSpeech[:SellItem]&.sample || "I can pay ${1}.\nWould that be OK?", price.to_s_formatted))
        old_money = @adapter.getMoney
        @adapter.setMoney(@adapter.getMoney + price)
        $stats.money_earned_at_marts += @adapter.getMoney - old_money
        qty.times { @adapter.removeItem(item) }
        Achievements.incrementProgress("ITEMS_SOLD",qty) if PluginManager.installed?("Mega MewThree's Achievement System")
        sold_item_name = (qty > 1) ? itemnameplural : itemname
        pbDisplayPaused(_INTL("You turned over the {1} and got ${2}.",
                              sold_item_name, price.to_s_formatted)) { pbSEPlay("Mart buy item") }
        @scene.pbRefresh
      end
      @scene.pbHideMoney
    end
    @scene.pbEndSellScene
  end
end

def forcePokemonMartRefresh
  return if $ArckyGlobal.pokeMartTracker.empty?
  $ArckyGlobal.pokeMartTracker.each do |mapID, events|
    events.each do |eventID, values|
      next if values[:refresh] == "never"
      $ArckyGlobal.pokeMartTracker[mapID][eventID] = nil 
    end 
  end
end 

def pbPokemonMart(stockWithLimit, speech = nil, useCat = false, discount = nil, cantsell = false)
  refreshRate, stock = extractStock(stockWithLimit)
  if !speech.is_a?(String) && !speech.is_a?(Numeric) # no speech given (optional useCat, discount and cantsell)
    cantsell = discount if discount
    discount = useCat if useCat
    useCat = speech
    speech = nil
  elsif speech.is_a?(Numeric) # only discount given (optional cantsell)
    cantsell = useCat if useCat
    discount = speech 
    useCat = false
    speech = nil
  elsif useCat.is_a?(Numeric) # speech and discount given (optional cantsell)
    discount = useCat
    useCat = false
  end 
  date = pbGetTimeNow.strftime("%Y-%m-%d")
  if stockWithLimit.any? {|item| item.is_a?(Array) }
    $ArckyGlobal.pokeMartTracker ||= {}
    $ArckyGlobal.pokeMartTracker[@map_id] ||= {}
    $ArckyGlobal.pokeMartTracker[@map_id][@event_id] ||= {}
    # get the days between the day that one item was out of stock and the day of checking again
    daysDiff = getPreviousRefreshDate(date)
    timeInDays = convertDays(refreshRate, daysDiff)
    if timeInDays.nil? && refreshRate != "never"
      $ArckyGlobal.pokeMartTracker[@map_id][@event_id] = {}
      daysDiff = getPreviousRefreshDate(date)
      timeInDays = convertDays(refreshRate, daysDiff)
    end 
    # canRefresh is true if the daysDiff is equal to the refreshRate day requirement.
    pokeMartTracker = $ArckyGlobal.pokeMartTracker[@map_id][@event_id]
    pokeMartTracker = { :date => date, :refresh => timeInDays, :items => getItemList(stockWithLimit.drop(1)) } if pokeMartTracker.empty?
    pokeMartTracker[:refresh] = timeInDays if !pokeMartTracker.empty?
  else 
    pokeMartTracker = nil
  end 
  APMSettings::BADGES_FOR_ITEMS.each do |badgeCount, badgeItems|
    if badgeCount > $player.badge_count
      badgeItems.each do |item|
        stock.delete(item)
      end
    end
  end
  stock.delete_if { |item| GameData::Item.get(item).is_important? && $bag.has?(item) }
  unless speech.nil?
    getSpeech = APMSettings.const_get(speech.gsub(" ", "")) if APMSettings.const_defined?(speech.gsub(" ", ""))
  else 
    getSpeech = {} if speech.nil?
  end 
  commands = []
  cmdBuy  = -1
  cmdSell = -1
  cmdQuit = -1
  commands[cmdBuy = commands.length]  = _INTL("I'm here to buy")
  commands[cmdSell = commands.length] = _INTL("I'm here to sell") if !cantsell
  commands[cmdQuit = commands.length] = _INTL("No, thanks")
  introText = getTimeOfDay(getSpeech, "Intro")
  cmd = pbMessage(_INTL(introText&.sample || "Welcome! How may I help you?"), commands, cmdQuit + 1)
  loop do
    catStock = []
    if cmdBuy >= 0 && cmd == cmdBuy
      if useCat
        stockByCat = Hash.new { |hash, key| hash[key] = [] } if useCat
        categoryHash = {}
        APMSettings::CATEGORY_NAMES.each_with_index do |name, index|
          order = (index + 1) * 10
          categoryHash[name] = { order: order }
        end 
        stock.each do |item|
          pocketName = APMSettings::CUSTOM_CATEGORY_NAMES.find { |category, list| list[:items].include?(item) }&.first
          if pocketName.nil?
            pocketID = GameData::Item.get(item).pocket
            pocketName = APMSettings::CATEGORY_NAMES[pocketID-1]
          end 
          stockByCat[pocketName] << item 
        end
        stockByCat = stockByCat.sort_by do |key, _|
          order = categoryHash[key]&.dig(:order) || APMSettings::CUSTOM_CATEGORY_NAMES[key]&.dig(:order)
          order || Float::INFINITY
        end.to_h
        choice = !speech.nil? && !(getSpeech[:CategoryText]&.empty?) ? pbMessage(_INTL(getSpeech[:CategoryText]&.sample), stockByCat.keys << "Go Back", -1) : 0
        if choice != -1 && choice != stockByCat.length
          choiceStock = stockByCat.values[choice]
        end 
      end 
      unless choiceStock.nil? && useCat
        scene = PokemonMart_Scene.new
        screen = PokemonMartScreen.new(scene, stock, speech, choiceStock, stockByCat, pokeMartTracker, discount)
        screen.pbBuyScreen 
      end
    elsif cmdSell >= 0 && cmd == cmdSell
      scene = PokemonMart_Scene.new
      screen = PokemonMartScreen.new(scene, stock, speech)
      screen.pbSellScreen
    else
      outroText = getTimeOfDay(getSpeech, "Outro")
      pbMessage(_INTL(outroText&.sample || "Do come again!"))
      break
    end
    cmd = pbMessage(_INTL(getSpeech[:MenuReturnText]&.sample || "Is there anything else I can do for you?"), commands, cmdQuit + 1)
  end
  $ArckyGlobal.pokeMartTracker[@map_id][@event_id] = $pokeMartTracker unless $pokeMartTracker.nil?
  $game_temp.clear_mart_prices
end

def getPreviousRefreshDate(date)
  pokeMartTracker = $ArckyGlobal.pokeMartTracker[@map_id][@event_id]
  return 0 if pokeMartTracker.empty?
  return (getDateFromString(date) - getDateFromString(pokeMartTracker[:date].to_s)) / (24 * 60 * 60)
end

def getDateFromString(date)
  dateArray = date.split('-')
  return Time.local(dateArray[0], dateArray[1], dateArray[2])
end 

def convertDays(refreshRate, daysDiff)
  case refreshRate.downcase
  when "daily"
    days = 1
  when "2daily"
    days = 2
  when "weekly"
    days = 7
  when "random"
    unless $ArckyGlobal.pokeMartTracker[@map_id][@event_id].empty?
      refresh = $ArckyGlobal.pokeMartTracker[@map_id][@event_id][:refresh]
      case refresh
      when "in a week"
        days = 7
      when /in (\d+) days/
        days = refresh[/\d+/].to_i
      when "tomorrow"
        days = 1
      end 
    else
      days = rand(1..7)
    end
  else 
    days = -1
  end 
  time = days - daysDiff
  case time
  when 1
    return "tomorrow"
  when 2..6
    return "in #{time.to_i} days"
  when 7
    return "in a week"
  else 
    return "never"
  end
end

def getItemList(stock)
  itemList = []
  newStock = stock.select { |item| item.is_a?(Array) && !item[1].nil? }
  newStock.each do |item|
    item[2] = item[1] if item[2].nil?
    if item[1] > item[2]
      Console.echoln_li _INTL("The min limit can't be bigger than the max limit for :#{item[0]}") 
      next
    end 
    entry = { :name => item[0], :limit => rand(item[1]..item[2])}
    itemList << entry
  end
  return itemList
end 

def extractStock(stock)
  if stock[0].is_a?(String)
    refreshRate = stock[0] 
    stock = stock.drop(1) 
  end 
  extractedStock = stock.map do |item|
    if item.is_a?(Array)
      item[0]
    else 
      item 
    end 
  end
  return refreshRate, extractedStock
end 

def getTimeOfDay(getSpeech, text)
  return if getSpeech.empty?
  weekDay = pbGetTimeNow.wday
  day = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday][weekDay]
  part = (weekDay == 0 || weekDay == 6) ? "Weekend" : "Week"
  time = if PBDayNight.isMorning?
            "Morning"
        elsif PBDayNight.isAfternoon?
            "Afternoon"
        elsif PBDayNight.isEvening?
            "Evening"
        elsif PBDayNight.isDay?
            "Day"
        elsif PBDayNight.isNight?
            "Night"
        end
  output = "#{text}#{day}#{time}".to_sym
  fallback = {
    "Morning" => ["#{text}TextMorning#{day}".to_sym, "#{text}TextDay#{day}".to_sym, "#{text}Text#{day}".to_sym, "#{text}TextMorning#{part}".to_sym, "#{text}TextDay#{part}".to_sym, "#{text}Text#{part}".to_sym, "#{text}TextMorning".to_sym, "#{text}TextDay".to_sym, "#{text}Text".to_sym],
    "Day" => ["#{text}TextDay#{day}".to_sym, "#{text}Text#{day}".to_sym, "#{text}TextDay#{part}".to_sym, "#{text}Text#{part}".to_sym, "#{text}TextDay".to_sym, "#{text}Text".to_sym],
    "Afternoon" => ["#{text}TextAfternoon#{day}".to_sym, "#{text}TextDay#{day}".to_sym, "#{text}Text#{day}".to_sym, "#{text}TextAfternoon#{part}".to_sym, "#{text}TextDay#{part}".to_sym, "#{text}Text#{part}".to_sym, "#{text}TextAfternoon".to_sym, "#{text}TextDay".to_sym, "#{text}Text".to_sym],
    "Evening" => ["#{text}TextEvening#{day}".to_sym, "#{text}TextDay#{day}".to_sym, "#{text}Text#{day}".to_sym, "#{text}TextEvening#{part}".to_sym, "#{text}TextDay#{part}".to_sym, "#{text}Text#{part}".to_sym, "#{text}TextEvening".to_sym, "#{text}TextDay".to_sym, "#{text}Text".to_sym],
    "Night" => ["#{text}TextNight#{day}".to_sym, "#{text}Text#{day}".to_sym, "#{text}TextNight#{part}".to_sym, "#{text}Text#{part}".to_sym, "#{text}TextNight".to_sym, "#{text}Text".to_sym]
  }
  fallbackOptions = fallback[time] || []
  fallbackOptions.each do |fallbackOption|
    return getSpeech[fallbackOption] unless getSpeech[fallbackOption]&.empty? || getSpeech[fallbackOption].nil?
  end
  return getSpeech[text.to_sym]
end 

class Window_PokemonMart < Window_DrawableCommand
  def initialize(stock, adapter, x, y, width, height, viewport = nil, pokeMartTracker = nil, discount)
    @stock       = stock
    @adapter     = adapter
    @pokeMartTracker = pokeMartTracker
    @discount    = discount
    super(x, y, width, height, viewport)
    if Essentials::VERSION.include?("21")
      @selarrow    = AnimatedBitmap.new("Graphics/UI/Mart/cursor")
    else 
      @selarrow    = AnimatedBitmap.new("Graphics/Pictures/martSel")
    end  
    @baseColor   = Color.new(88, 88, 80)
    @shadowColor = Color.new(168, 184, 184)
    @baseColor2  = Color.new(160, 160, 168)
    @shadowColor2 = Color.new(208, 208, 216)
    self.windowskin = nil
  end

  def itemCount
    return @stock.length + 1
  end

  def item
    return (self.index >= @stock.length) ? nil : @stock[self.index]
  end

  def drawItem(index, count, rect)
    textpos = []
    rect = drawCursor(index, rect)
    ypos = rect.y
    if index == count - 1
      textpos.push([_INTL("CANCEL"), rect.x, ypos + 2, :left, self.baseColor, self.shadowColor])
    else
      item = @stock[index]
      itemname = @adapter.getDisplayName(item)
      qty = @adapter.getDisplayPrice(item, @discount)
      entry = @pokeMartTracker[:items].find { |entry| entry[:name] == item} if !@pokeMartTracker.nil?
      qty = "Out of Stock" if !entry.nil? && entry[:limit] == 0 
      baseColor = qty == "Out of Stock" ? @baseColor2 : self.baseColor
      shadowColor = qty == "Out of Stock" ? @shadowColor2 : self.shadowColor
      sizeQty = self.contents.text_size(qty).width
      xQty = rect.x + rect.width - sizeQty - 2 - 16
      textpos.push([itemname, rect.x, ypos + 2, :left, baseColor, self.shadowColor])
      textpos.push([qty, xQty, ypos + 2, :left, baseColor, self.shadowColor])
    end
    pbDrawTextPositions(self.contents, textpos)
  end
end