#===============================================================================
#  Cregs EV Allocation
#  A custom script to allow the easy allocation of EVs after obtaining them.
#===============================================================================

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------

EV_GAIN_MODE = "Standard"  # Set to either "Standard" or "Level"
                          # "Standard" mode gains EVs when defeating an enemy Pokémon, as normal.
                          # "Level" mode gives EV_PER_LEVEL EVs upon levelling up, and any missing EVs to reach the cap at level 100.

EV_PER_LEVEL = 5          # The number of EVs gained per level in "Level" mode.
                          # When a wild Pokémon is generated, is also multiplied by the level to get
                          # the starting number of EVs.

EV_ON_CREATION = "Level" # Set to either "None", "Level" or "IV"
                            # "None" mode generates wild Pokémon with 0 buffered EVs by default.
                            # "Level" mode generates wild Pokémon with buffered EVs to EV_PER_LEVEl * Level
                            # "IV" mode generates wild Pokémon with buffered EVs equal to the sum of it's IVs & a percentage based on it's current level
                            #   EG, at level 5 the Pokémon gets 5% of the sum of it's IVs as EVs.

SCATTER_EVS_ON_CREATION = true  # Set to true to have buffered EVs distributed randomly when a Pokémon is created.
                                # Set to false to have a newly generated Pokémon's EVs remain in the buffer.

EV_SCATTER_MODE = "Biased"       # Set to either "Standard" or "Biased" or "Balanced"
                                # "Standard" mode scatters EVs on creation completely randomly.
                                # "Biased" mode scatters EVs on creation in a way that favours the Pokémon's higher base stats.
                                # "Balanced" mode scatters the EVs as evenly as possible between the Pokémon's stats.

#-------------------------------------------------------------------------------
# Edits to Pokemon class
#-------------------------------------------------------------------------------
class Pokemon
  # Integer value of accumulated EVs that need allocated.
  attr_accessor :ev_buffer

  alias ev_allocation_initialize initialize
  def initialize(*args)
    ev_allocation_initialize(*args)
    @ev_buffer = 0
    # Create and potentially scatter EVs if:
    # A. Pokemon is not already defined with EVs (IE Trainer battles)
    # B. Approprate rules are enabled.
    @ev_buffer = getDefaultEVs if EV_ON_CREATION != "None"
    scatterEVs if SCATTER_EVS_ON_CREATION == true
  end

# Method to return the EV Buffer.
# Also creates the EV buffer, which is for backwards compatability of old saves.
  def evBuffer
    @ev_buffer = 0 if !@ev_buffer
    return @ev_buffer
  end

# Method to increase the EV buffer. Used for UI functionality.
 def increaseEVBuffer(value)
   @ev_buffer += value
 end

# Method to decrease the EV Buffer. Used for UI functionality.
 def decreaseEVBuffer(value)
   @ev_buffer -= value
 end

# Method to check if the Pokemon can have it's EVs reset.
# Called by pbResetAllEffortValues
 def pbCanResetEVs?
   GameData::Stat.each_main do |stat|
     return true if @ev[stat.id] > 0
   end
   return false
 end

  # Method to calculate total EVs - includes allocated EVs and EVs in the buffer.
  def totalEVs
    ret = 0
    ret += self.evBuffer
    GameData::Stat.each_main do |stat|
      ret += @ev[stat.id]
    end
    return ret
  end

  # Method to get the default EVs when a Pokémon is created.
  def getDefaultEVs
    case EV_ON_CREATION
    # No buffered EVs on creation.
    when "None"
      return 0
    # Buffered EVs on creation are equal to EV_PER_LEVEl * level.
    when "Level"
      return EV_PER_LEVEL * level
    # Buffered EVs on creation are equal to level% of the sum of the Pokémon's IVs.
    when "IV"
      stats = [:HP,:ATTACK,:DEFENSE,:SPECIAL_ATTACK,:SPECIAL_DEFENSE,:SPEED]
      ret = 0
      for stat in stats
        ret += self.iv[stat]
      end
      percent = level.to_f/100
      ret *= percent
      ret = ret.round()
      return ret
    end
  end

  # Method to randomly allocate all buffered EVs on creation.
  def scatterEVs
    stats = [:HP,:ATTACK,:DEFENSE,:SPECIAL_ATTACK,:SPECIAL_DEFENSE,:SPEED]
    # Standard mode scatters EVs completely randomly.
    if EV_SCATTER_MODE == "Standard"
      @ev_buffer.times do
        break if @ev_buffer <= 0
        stat = rand(6)
        @ev[stats[stat]] += 1
        @ev_buffer -= 1
      end
    # Biased mode trends towards higher base stats.
    elsif EV_SCATTER_MODE == "Biased"
      bst = baseStatTotal
      base_stats = baseStats
      @ev_buffer.times do
        break if @ev_buffer <= 0
        randNum = rand(bst)
        for stat in stats
          num = base_stats[stat]
          if randNum < num
            @ev[stat] += 1
            @ev_buffer -= 1
            break
          else
            randNum -= num
            next
          end
        end
      end
    # Balanced mode scatters EVs evenly between stats.
    elsif EV_SCATTER_MODE == "Balanced"
      i = 0
      @ev_buffer.times do
        break if @ev_buffer <= 0
        @ev[stats[i]] += 1
        i += 1; i = 0 if i > 5
        @ev_buffer -=1
      end
    end
  end

  # Quick easy BST calculation
  def baseStatTotal
    ret = 0
    base_stats = baseStats
    GameData::Stat.each_main { |s| ret += base_stats[s.id] }
    return ret
  end

  # EV Yield is set to a single number, based on the existing EV yield defined in the PBS.
  # EG. Bulbasaur gives 1 EV, Ivysaur 2, and Venusaur 3.
  # This is to allow the stats to be allocated freely, rather than determined by the wild Pokémon.
  def evYield
    this_evs = species_data.evs
    ret = 0
    GameData::Stat.each_main { |s| ret += this_evs[s.id] }
    return ret
  end

  # Function used to calculate EV yield on level up.
  def gainEVBuffer(scene,earned=0,leveldiff=0, showmessage = true)
    if EV_GAIN_MODE == "Standard"
      ev_yield = earned
    elsif EV_GAIN_MODE == "Level"
      ev_yield = EV_PER_LEVEL * leveldiff
    end
    # ev_yield = EV_PER_LEVEL
    # ev_yield *= leveldiff
    # Double EV gain because of Pokérus
    if self.pokerusStage>=1   # Infected or cured
      ev_yield *= 2
    end
    # Max out EVs at max level if in level mode.
    if self.level == 100 && EV_GAIN_MODE == "Level"
      ev_yield = Pokemon::EV_LIMIT - self.totalEVs
    else
    end
    ev_yield = ev_yield.clamp(0, Pokemon::EV_LIMIT - self.totalEVs)
    if ev_yield > 0
      @ev_buffer += ev_yield
      # Do message
      if showmessage == true
        if scene.is_a?(PokemonPartyScreen) || scene.is_a?(Battle::Scene)
          scene.pbDisplay(_INTL("{1} gained {2} EVs!",self.name,ev_yield))
        else
          pbMessage(_INTL("{1} gained {2} EVs!",self.name,ev_yield))
        end
      end
    end
  end
end
#-------------------------------------------------------------------------------
# Edits to Battle
#-------------------------------------------------------------------------------
# Pokémon will only gain EVs after defeating an enemy battler IF the EV_GAIN_MODE
# is set to "Vanilla"
class Battle
  def pbGainEVsOne(idxParty,defeatedBattler)
    if EV_GAIN_MODE == "Standard"
      pkmn = pbParty(0)[idxParty]   # The Pokémon gaining EVs from defeatedBattler
      ev_yield = defeatedBattler.pokemon.evYield
      # Modify EV yield based on pkmn's held item
      if !Battle::ItemEffects.triggerEVGainModifier(pkmn.item,pkmn,ev_yield)
        Battle::ItemEffects.triggerEVGainModifier(@initialItems[0][idxParty],pkmn,ev_yield)
      end
      # Add to the Pokémon's EV Buffer
      pkmn.gainEVBuffer(@scene, ev_yield, nil, false)
    end
  end
end
#-------------------------------------------------------------------------------
# Edits to Battle::Scene
#-------------------------------------------------------------------------------
class Battle::Scene
  alias ev_allocation_level_up pbLevelUp
  def pbLevelUp(*args)
    ev_allocation_level_up(*args)
    if EV_GAIN_MODE == "Level"
      pkmn = args[0]
      pkmn.gainEVBuffer(self, nil, 1)
    end
  end
end

#-------------------------------------------------------------------------------
# Edits to Items (For Rare Candy + EXP Candies)
#-------------------------------------------------------------------------------
#===============================================================================
# Change a Pokémon's level
#===============================================================================
def pbChangeLevel(pkmn,newlevel,scene,checkmoves = false)
  oldlevel = pkmn.level
  newlevel = newlevel.clamp(1, GameData::GrowthRate.max_level)
  if pkmn.level==newlevel
    pbMessage(_INTL("{1}'s level remained unchanged.",pkmn.name))
  elsif pkmn.level>newlevel
    attackdiff  = pkmn.attack
    defensediff = pkmn.defense
    speeddiff   = pkmn.speed
    spatkdiff   = pkmn.spatk
    spdefdiff   = pkmn.spdef
    totalhpdiff = pkmn.totalhp
    pkmn.level = newlevel
    pkmn.calc_stats
    scene.pbRefresh
    pbMessage(_INTL("{1} dropped to Lv. {2}!",pkmn.name,pkmn.level))
    attackdiff  = pkmn.attack-attackdiff
    defensediff = pkmn.defense-defensediff
    speeddiff   = pkmn.speed-speeddiff
    spatkdiff   = pkmn.spatk-spatkdiff
    spdefdiff   = pkmn.spdef-spdefdiff
    totalhpdiff = pkmn.totalhp-totalhpdiff
    pbTopRightWindow(_INTL("Max. HP<r>{1}\r\nAttack<r>{2}\r\nDefense<r>{3}\r\nSp. Atk<r>{4}\r\nSp. Def<r>{5}\r\nSpeed<r>{6}",
       totalhpdiff,attackdiff,defensediff,spatkdiff,spdefdiff,speeddiff))
    pbTopRightWindow(_INTL("Max. HP<r>{1}\r\nAttack<r>{2}\r\nDefense<r>{3}\r\nSp. Atk<r>{4}\r\nSp. Def<r>{5}\r\nSpeed<r>{6}",
       pkmn.totalhp,pkmn.attack,pkmn.defense,pkmn.spatk,pkmn.spdef,pkmn.speed))
  else
    attackdiff  = pkmn.attack
    defensediff = pkmn.defense
    speeddiff   = pkmn.speed
    spatkdiff   = pkmn.spatk
    spdefdiff   = pkmn.spdef
    totalhpdiff = pkmn.totalhp
    pkmn.level = newlevel
    pkmn.changeHappiness("vitamin")
    pkmn.calc_stats
    scene.pbRefresh
    if scene.is_a?(PokemonPartyScreen)
      scene.pbDisplay(_INTL("{1} grew to Lv. {2}!",pkmn.name,pkmn.level))
    else
      pbMessage(_INTL("{1} grew to Lv. {2}!",pkmn.name,pkmn.level))
    end
    attackdiff  = pkmn.attack-attackdiff
    defensediff = pkmn.defense-defensediff
    speeddiff   = pkmn.speed-speeddiff
    spatkdiff   = pkmn.spatk-spatkdiff
    spdefdiff   = pkmn.spdef-spdefdiff
    totalhpdiff = pkmn.totalhp-totalhpdiff
    pbTopRightWindow(_INTL("Max. HP<r>+{1}\r\nAttack<r>+{2}\r\nDefense<r>+{3}\r\nSp. Atk<r>+{4}\r\nSp. Def<r>+{5}\r\nSpeed<r>+{6}",
       totalhpdiff,attackdiff,defensediff,spatkdiff,spdefdiff,speeddiff),scene)
    pbTopRightWindow(_INTL("Max. HP<r>{1}\r\nAttack<r>{2}\r\nDefense<r>{3}\r\nSp. Atk<r>{4}\r\nSp. Def<r>{5}\r\nSpeed<r>{6}",
       pkmn.totalhp,pkmn.attack,pkmn.defense,pkmn.spatk,pkmn.spdef,pkmn.speed),scene)
    # Here is where EV gain goes.
    if EV_GAIN_MODE == "Level"
      level_diff = newlevel - oldlevel
      pkmn.gainEVBuffer(scene, nil, level_diff)
    end
    # Learn new moves upon level up
    movelist = pkmn.getMoveList
    for i in movelist
      if checkmoves
        next if i[0] <= oldlevel || i[0] > pkmn.level
      else
        next if i[0] != pkmn.level
      end
      pbLearnMove(pkmn, i[1], true) { scene.pbUpdate }
    end
    # Check for evolution
    newspecies = pkmn.check_evolution_on_level_up
    if newspecies
      pbFadeOutInWithMusic {
        evo = PokemonEvolutionScene.new
        evo.pbStartScreen(pkmn,newspecies)
        evo.pbEvolution
        evo.pbEndScreen
        scene.pbRefresh if scene.is_a?(PokemonPartyScreen)
      }
    end
  end
end
#-------------------------------------------------------------------------------
# Edits to Summary Screen
#-------------------------------------------------------------------------------
# The following changes allow buffered EVs to be modified in the summary screen.

class PokemonSummary_Scene

  alias ev_allocation_start_summary pbStartScene
  def pbStartScene(*args)
    ev_allocation_start_summary(*args)
    @viewing_evs  = false
    @edit_evs     = false
    @sprites["evsel"] = EVSelectionSprite.new(@viewport)
    @sprites["evsel"].visible = false

    # Create stat buttons, then hide them.
    @pokemon = args[0][args[1]]
    start_x = 64; start_y = 60; i = 0
    # GameData::Stat.each_main do |stat|
    #   x = start_x; y = start_y + (34*i)
    #   @sprites["ev_button_#{stat.id}"] = EVSelectionSprite.new(@viewport)
    #   @sprites["ev_button_#{stat.id}"].visible = false
    #   i+=1
    # end
  end

  def drawPageThree
    overlay = @sprites["overlay"].bitmap
    base   = Color.new(248,248,248)
    shadow = Color.new(104,104,104)
    # Determine which stats are boosted and lowered by the Pokémon's nature
    statshadows = {}
    GameData::Stat.each_main { |s| statshadows[s.id] = shadow }
    if !@pokemon.shadowPokemon? || @pokemon.heartStage > 3
      @pokemon.nature_for_stats.stat_changes.each do |change|
        statshadows[change[0]] = Color.new(191,158,145) if change[1] > 0
        statshadows[change[0]] = Color.new(145,158,191) if change[1] < 0
      end
    end
    # Write various bits of text
    textpos = [
       [_INTL("HP"),292,82,2,base,statshadows[:HP]],
       [_INTL("Attack"),248,126,0,base,statshadows[:ATTACK]],
       [_INTL("Defense"),248,158,0,base,statshadows[:DEFENSE]],
       [_INTL("Sp. Atk"),248,190,0,base,statshadows[:SPECIAL_ATTACK]],
       [_INTL("Sp. Def"),248,222,0,base,statshadows[:SPECIAL_DEFENSE]],
       [_INTL("Speed"),248,254,0,base,statshadows[:SPEED]],
    ]
    if !@viewing_evs
      textpos.push(
        [sprintf("%d/%d",@pokemon.hp,@pokemon.totalhp),462,82,1,Color.new(64,64,64),Color.new(176,176,176)],
        [sprintf("%d",@pokemon.attack),456,126,1,Color.new(64,64,64),Color.new(176,176,176)],
        [sprintf("%d",@pokemon.defense),456,158,1,Color.new(64,64,64),Color.new(176,176,176)],
        [sprintf("%d",@pokemon.spatk),456,190,1,Color.new(64,64,64),Color.new(176,176,176)],
        [sprintf("%d",@pokemon.spdef),456,222,1,Color.new(64,64,64),Color.new(176,176,176)],
        [sprintf("%d",@pokemon.speed),456,254,1,Color.new(64,64,64),Color.new(176,176,176)],
        [_INTL("Ability"),224,290,0,base,shadow]
      )
      # Draw ability name and description
      ability = @pokemon.ability
      if ability
        textpos.push([ability.name,362,290,0,Color.new(64,64,64),Color.new(176,176,176)])
        drawTextEx(overlay,224,320,282,2,ability.description,Color.new(64,64,64),Color.new(176,176,176))
      end
    # If viewing the EVs
    elsif @viewing_evs
      @available = @pokemon.evBuffer
      @sprites["background"].setBitmap("Graphics/UI/Summary/bg_3_ev.png")
      textpos.push(
        [sprintf("%d/%d",@pokemon.ev[:HP],Pokemon::EV_STAT_LIMIT),462,82,1,Color.new(64,64,64),Color.new(176,176,176)],
        [sprintf("%d/%d",@pokemon.ev[:ATTACK],Pokemon::EV_STAT_LIMIT),456,126,1,Color.new(64,64,64),Color.new(176,176,176)],
        [sprintf("%d/%d",@pokemon.ev[:DEFENSE],Pokemon::EV_STAT_LIMIT),456,158,1,Color.new(64,64,64),Color.new(176,176,176)],
        [sprintf("%d/%d",@pokemon.ev[:SPECIAL_ATTACK],Pokemon::EV_STAT_LIMIT),456,190,1,Color.new(64,64,64),Color.new(176,176,176)],
        [sprintf("%d/%d",@pokemon.ev[:SPECIAL_DEFENSE],Pokemon::EV_STAT_LIMIT),456,222,1,Color.new(64,64,64),Color.new(176,176,176)],
        [sprintf("%d/%d",@pokemon.ev[:SPEED],Pokemon::EV_STAT_LIMIT),456,254,1,Color.new(64,64,64),Color.new(176,176,176)],
        [_INTL("Free EVs:"), 248, 298, 0, base, shadow],
        [sprintf("%d",@pokemon.evBuffer), 464,298, 1,Color.new(64,64,64),Color.new(176,176,176)],
        [_INTL("Total EVs:"), 248, 330, 0, base, shadow],
        [sprintf("%d",@pokemon.totalEVs), 464,330, 1,Color.new(64,64,64),Color.new(176,176,176)]
      )
    end
    # Draw all text
    pbDrawTextPositions(overlay,textpos)
    # Draw HP bar
    if @pokemon.hp>0
      w = @pokemon.hp*96*1.0/@pokemon.totalhp
      w = 1 if w<1
      w = ((w/2).round)*2
      hpzone = 0
      hpzone = 1 if @pokemon.hp<=(@pokemon.totalhp/2).floor
      hpzone = 2 if @pokemon.hp<=(@pokemon.totalhp/4).floor
      imagepos = [
         ["Graphics/UI/Summary/overlay_hp.png",360,110,0,hpzone*6,w,6]
      ]
      pbDrawImagePositions(overlay,imagepos)
    end
  end

  def pbEVAllocate
    stat_index = 0
    stats = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]
    @allocation = [0,0,0,0,0,0]
    @sprites["evsel"].visible = true
    @sprites["evsel"].index = 0
    for i in 0..5
      y = 85 + (i*32)
      y += 12 if i>0
      @sprites["ev_counter_#{i}"] = EVOverlaySprite.new(@viewport, 332, y)
      @sprites["ev_counter_#{i}"].visible = false
    end
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if Input.trigger?(Input::BACK)
        if @allocation.sum > 0
          if pbConfirmMessage(_INTL("Cancel EV allocation?"))
            pbPlayCancelSE
            break
          end
        else
          pbPlayCancelSE
          break
        end
      elsif Input.trigger?(Input::USE)
        if @allocation.sum > 0
          if pbConfirmMessage(_INTL("Apply EVs?"))
            pbPlayDecisionSE
            @pokemon.decreaseEVBuffer(@allocation.sum)
            for i in 0..5
              @pokemon.ev[stats[i]] += @allocation[i]
            end
            @pokemon.calc_stats
            break
          end
        else
          pbPlayCancelSE
          break
        end
      elsif Input.trigger?(Input::LEFT)
        pbChangeAllocation(mode="Down", amount=1, stat_index)
      elsif Input.trigger?(Input::JUMPDOWN)
        pbChangeAllocation(mode="Up", amount=10, stat_index)
      elsif Input.trigger?(Input::RIGHT)
        pbChangeAllocation(mode="Up", amount=1, stat_index)
      elsif Input.trigger?(Input::JUMPUP)
        pbChangeAllocation(mode="Down", amount=10, stat_index)
      elsif Input.trigger?(Input::UP)
        stat_index -= 1
        stat_index = 5 if stat_index < 0
        @sprites["evsel"].index = stat_index
      elsif Input.trigger?(Input::DOWN)
        stat_index += 1
        stat_index = 0 if stat_index > 5
        @sprites["evsel"].index = stat_index
      end
    end
    @sprites["evsel"].visible = false
    for i in 0..5
      @sprites["ev_counter_#{i}"].visible = false
    end
  end

  def pbChangeAllocation(mode="Up", amount=1, index)
    stats = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]
    if mode == "Up"
      return if !pbCanIncreaseEV(stats[index],index,amount)
      amount = amount.clamp(0,[@available, Pokemon::EV_STAT_LIMIT - (@pokemon.ev[stats[index]] + @allocation[index]), Pokemon::EV_STAT_LIMIT].min)
      @allocation[index] += amount
      @available -= amount
    elsif mode == "Down"
      return if !pbCanDecreaseEV(stats[index],index)
      amount = amount.clamp(0,@allocation[index])
      @allocation[index] -= amount
      @available += amount
    end
    @sprites["ev_counter_#{index}"].updateValue(@allocation[index])
  end

  def pbCanIncreaseEV(stat,index,amount=1)
    return false if @pokemon.ev[stat] >= Pokemon::EV_STAT_LIMIT
    return false if @allocation.sum >= @pokemon.evBuffer
    return true
  end

  def pbCanDecreaseEV(stat,index)
    return false if @allocation[index] <= 0
    return true
  end

  def pbScene
    @pokemon.play_cry
    loop do
      Graphics.update
      Input.update
      pbUpdate
      dorefresh = false
      if Input.trigger?(Input::ACTION)
        # Literally the only change is here, though, so it might be better to just
        # copy-paste this section to replace the one in UI_Summary
        if @page==3
          @viewing_evs = !@viewing_evs
          dorefresh=true
        else
          pbSEStop
          @pokemon.play_cry
        end
      elsif Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      elsif Input.trigger?(Input::USE)
        # The only other change
        if @page == 3 && @viewing_evs && !@inbattle
          #if @pokemon.evBuffer <= 0
            #pbMessage(_INTL("{1} has no EVs available.",@pokemon.name))
          #else
            if pbConfirmMessage(_INTL("Allocate EVs?"))
              pbEVAllocate
            end
          #end
          dorefresh = true
        elsif @page==4
          pbPlayDecisionSE
          pbMoveSelection
          dorefresh = true
        elsif @page==5
          pbPlayDecisionSE
          pbRibbonSelection
          dorefresh = true
        elsif !@inbattle
          pbPlayDecisionSE
          dorefresh = pbOptions
        end
      elsif Input.trigger?(Input::UP) && @partyindex>0
        oldindex = @partyindex
        pbGoToPrevious
        if @partyindex!=oldindex
          pbChangePokemon
          @ribbonOffset = 0
          dorefresh = true
        end
      elsif Input.trigger?(Input::DOWN) && @partyindex<@party.length-1
        oldindex = @partyindex
        pbGoToNext
        if @partyindex!=oldindex
          pbChangePokemon
          @ribbonOffset = 0
          dorefresh = true
        end
      elsif Input.trigger?(Input::LEFT) && !@pokemon.egg?
        oldpage = @page
        @page -= 1
        @page = 1 if @page<1
        @page = 5 if @page>5
        if @page!=oldpage   # Move to next page
          pbSEPlay("GUI summary change page")
          @ribbonOffset = 0
          dorefresh = true
        end
      elsif Input.trigger?(Input::RIGHT) && !@pokemon.egg?
        oldpage = @page
        @page += 1
        @page = 1 if @page<1
        @page = 5 if @page>5
        if @page!=oldpage   # Move to next page
          pbSEPlay("GUI summary change page")
          @ribbonOffset = 0
          dorefresh = true
        end
      end
      if dorefresh
        drawPage(@page)
      end
    end
    return @partyindex
  end
# End of class
end

#-------------------------------------------------------------------------------
# New selection sprite
#-------------------------------------------------------------------------------
class EVSelectionSprite < MoveSelectionSprite
  def initialize(viewport=nil)
    super(viewport)
    @movesel = AnimatedBitmap.new("Graphics/UI/Summary/cursor_ev.png")
    @frame = 0
    @index = 0
    @preselected = false
    @updating = false
    @spriteVisible = true
    refresh
  end

  def visible=(value)
    super
    @spriteVisible = value if !@updating
  end

  def refresh
    w = @movesel.width
    h = @movesel.height/2
    self.x = 234
    self.y = 72 + (self.index*32)
    self.y += 14 if self.index > 0
    self.bitmap = @movesel.bitmap
    if self.preselected
      self.src_rect.set(0,h,w,h)
    else
      self.src_rect.set(0,0,w,h)
    end
  end

  def update
    @updating = true
    super
    self.visible = @spriteVisible && @index>=0 && @index<12
    @movesel.update
    @updating = false
    refresh
  end
end
#-------------------------------------------------------------------------------
# New overlay sprite
#-------------------------------------------------------------------------------
class EVOverlaySprite < Sprite
  def initialize(viewport = nil,x,y)
    super(viewport)
    @thisbitmap = BitmapWrapper.new(162, 48)
    pbSetSmallFont(@thisbitmap)
    self.x = x; self.y = y
    self.bitmap = @thisbitmap
    @allocating = 0
    # Draw text
    refresh
  end

  def selected=(value)
    @selected = value
  end

  def dispose
    @thisbitmap.dispose
    super
  end

  def updateValue(value)
    @allocating = value
    refresh
  end

  def refresh
    self.bitmap.clear
    self.visible = @allocating > 0 ? true : false
    textpos = [
       [_INTL("+#{@allocating}"),0,0,0,Color.new(24,192,32),Color.new(0,144,0)],
    ]
    pbDrawTextPositions(self.bitmap,textpos)
  end
end

#-------------------------------------------------------------------------------
# New debug command
#-------------------------------------------------------------------------------
MenuHandlers.add(:pokemon_debug_menu, :hidden_values, {
  "parent"      => :level_stats,
  "name"        => _INTL("EV/IV/pID..."),
  "effect"      => proc { |pkmn, pkmnid, heldpoke, settingUpBattle, screen|
    cmd = 0
    loop do
      persid = sprintf("0x%08X", pkmn.personalID)
      cmd = screen.pbShowCommands(_INTL("Personal ID is {1}.", persid), [
           _INTL("Set EV Buffer"),
           _INTL("Set EVs"),
           _INTL("Set IVs"),
           _INTL("Randomise pID")], cmd)
      break if cmd < 0
      case cmd
      when 0
        totalev = 0
        GameData::Stat.each_main do |s|
          totalev += pkmn.ev[s.id]
        end
        params = ChooseNumberParams.new
        params.setRange(0, (Pokemon::EV_LIMIT-totalev))
        params.setDefaultValue(pkmn.evBuffer)
        buffer = pbMessageChooseNumber(
           _INTL("Set the Pokémon's EV buffer (max. {1}).", params.maxNumber), params) { screen.pbUpdate }
        if buffer != pkmn.evBuffer
          pkmn.ev_buffer = buffer
          pkmn.calc_stats
          screen.pbRefreshSingle(pkmnid)
        end
      when 1   # Set EVs
        cmd2 = 0
        loop do
          totalev = 0
          evcommands = []
          ev_id = []
          GameData::Stat.each_main do |s|
            evcommands.push(s.name + " (#{pkmn.ev[s.id]})")
            ev_id.push(s.id)
            totalev += pkmn.ev[s.id]
          end
          evcommands.push(_INTL("Randomise all"))
          evcommands.push(_INTL("Max randomise all"))
          cmd2 = screen.pbShowCommands(_INTL("Change which EV?\nTotal: {1}/{2} ({3}%)",
                                      totalev, Pokemon::EV_LIMIT,
                                      100 * totalev / Pokemon::EV_LIMIT), evcommands, cmd2)
          break if cmd2 < 0
          if cmd2 < ev_id.length
            params = ChooseNumberParams.new
            upperLimit = 0
            GameData::Stat.each_main { |s| upperLimit += pkmn.ev[s.id] if s.id != ev_id[cmd2] }
            upperLimit = Pokemon::EV_LIMIT - upperLimit
            upperLimit = [upperLimit, Pokemon::EV_STAT_LIMIT].min
            thisValue = [pkmn.ev[ev_id[cmd2]], upperLimit].min
            params.setRange(0, upperLimit)
            params.setDefaultValue(thisValue)
            params.setCancelValue(thisValue)
            f = pbMessageChooseNumber(_INTL("Set the EV for {1} (max. {2}).",
               GameData::Stat.get(ev_id[cmd2]).name, upperLimit), params) { screen.pbUpdate }
            if f != pkmn.ev[ev_id[cmd2]]
              pkmn.ev[ev_id[cmd2]] = f
              pkmn.calc_stats
              screen.pbRefreshSingle(pkmnid)
            end
          else   # (Max) Randomise all
            evTotalTarget = Pokemon::EV_LIMIT
            if cmd2 == evcommands.length - 2   # Randomize all (not max)
              evTotalTarget = rand(Pokemon::EV_LIMIT)
            end
            GameData::Stat.each_main { |s| pkmn.ev[s.id] = 0 }
            while evTotalTarget > 0
              r = rand(ev_id.length)
              next if pkmn.ev[ev_id[r]] >= Pokemon::EV_STAT_LIMIT
              addVal = 1 + rand(Pokemon::EV_STAT_LIMIT / 4)
              addVal = addVal.clamp(0, evTotalTarget)
              addVal = addVal.clamp(0, Pokemon::EV_STAT_LIMIT - pkmn.ev[ev_id[r]])
              next if addVal == 0
              pkmn.ev[ev_id[r]] += addVal
              evTotalTarget -= addVal
            end
            pkmn.calc_stats
            screen.pbRefreshSingle(pkmnid)
          end
        end
      when 2   # Set IVs
        cmd2 = 0
        loop do
          hiddenpower = pbHiddenPower(pkmn)
          totaliv = 0
          ivcommands = []
          iv_id = []
          GameData::Stat.each_main do |s|
            ivcommands.push(s.name + " (#{pkmn.iv[s.id]})")
            iv_id.push(s.id)
            totaliv += pkmn.iv[s.id]
          end
          msg = _INTL("Change which IV?\nHidden Power:\n{1}, power {2}\nTotal: {3}/{4} ({5}%)",
             GameData::Type.get(hiddenpower[0]).name, hiddenpower[1], totaliv,
             iv_id.length * Pokemon::IV_STAT_LIMIT, 100 * totaliv / (iv_id.length * Pokemon::IV_STAT_LIMIT))
          ivcommands.push(_INTL("Randomise all"))
          cmd2 = screen.pbShowCommands(msg, ivcommands, cmd2)
          break if cmd2 < 0
          if cmd2 < iv_id.length
            params = ChooseNumberParams.new
            params.setRange(0, Pokemon::IV_STAT_LIMIT)
            params.setDefaultValue(pkmn.iv[iv_id[cmd2]])
            params.setCancelValue(pkmn.iv[iv_id[cmd2]])
            f = pbMessageChooseNumber(_INTL("Set the IV for {1} (max. 31).",
               GameData::Stat.get(iv_id[cmd2]).name), params) { screen.pbUpdate }
            if f != pkmn.iv[iv_id[cmd2]]
              pkmn.iv[iv_id[cmd2]] = f
              pkmn.calc_stats
              screen.pbRefreshSingle(pkmnid)
            end
          else   # Randomise all
            GameData::Stat.each_main { |s| pkmn.iv[s.id] = rand(Pokemon::IV_STAT_LIMIT + 1) }
            pkmn.calc_stats
            screen.pbRefreshSingle(pkmnid)
          end
        end
      when 3   # Randomise pID
        pkmn.personalID = rand(2 ** 16) | rand(2 ** 16) << 16
        pkmn.calc_stats
        screen.pbRefreshSingle(pkmnid)
      end
    end
    next false
  }
})

#===============================================================================
# Method to reset all EVs.
#===============================================================================
def pbResetAllEffortValues(pkmn)
  return false if !pkmn.pbCanResetEVs?
  GameData::Stat.each_main do |stat|
    pkmn.increaseEVBuffer(pkmn.ev[stat.id])
    pkmn.ev[stat.id] = 0 if pkmn.ev[stat.id] != 0
  end
  pkmn.calc_stats
end
