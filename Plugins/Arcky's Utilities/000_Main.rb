SaveData.register(:arckyglobal) do
  load_in_bootup
  ensure_class :ArckyGlobalData
  save_value { $ArckyGlobal }
  load_value { |value| $ArckyGlobal = value }
  new_game_value { ArckyGlobalData.new }
  reset_on_new_game
end

class ArckyGlobalData
  # Custom Trackers
  attr_accessor :itemTracker
  attr_accessor :trainerTracker
  attr_accessor :mapVisitTracker
  attr_accessor :pokeMartTracker

  # Custom Pokedex Trackers
  attr_accessor :seenSpeciesCount
  attr_accessor :seenSpeciesCountMap
  attr_accessor :caughtSpeciesCount
  attr_accessor :caughtSpeciesCountMap
  attr_accessor :defeatedSpeciesCount
  attr_accessor :defeatedSpeciesCountMap

  def initialize
    echoln("do we do this now?")
    # Custom Trackers
    @itemTracker                = {} # ok
    @trainerTracker             = {} # ok
    @mapVisitTracker            = {} # ok
    @pokeMartTracker            = {} # ok

    # Custom Pokedex Trackers
    @seenSpeciesCount           = {}
    @seenSpeciesCountMap        = {}
    @caughtSpeciesCount         = {}
    @caughtSpeciesCountMap      = {}
    @defeatedSpeciesCount       = {}
    @defeatedSpeciesCountMap    = {}
  end
end

SEEN     = :seen
CAUGHT   = :caught
DEFEATED = :defeated 
GENDER   = :gender 
FORM     = :form 
SHINY    = :shiny 

# Utilities
def getDistrictName(mapPos, mapData = nil)
  return "" if mapPos.nil?
  mapPos = mapPos.town_map_position if !mapPos.is_a?(Array)
  mapData = pbLoadTownMapData if mapData.nil? && Essentials::VERSION.include?("20")
  mapData = GameData::TownMap.get(mapPos[0]) if mapData.nil?
  regionName = Essentials::VERSION.include?("20") ? MessageTypes::RegionNames : MessageTypes::REGION_NAMES
  if ARMSettings::USE_REGION_DISTRICTS_NAMES
    ARMSettings::REGION_DISTRICTS.each do |region, rangeX, rangeY, districtName|
      if mapPos[0] == region && mapPos[1].between?(rangeX[0], rangeX[1]) && mapPos[2].between?(rangeY[0], rangeY[1])
        scripts = Essentials::VERSION.include?("20") ? MessageTypes::ScriptTexts : MessageTypes::SCRIPT_TEXTS
        return pbGetMessageFromHash(scripts, districtName)
      end 
    end 
  end 
  return pbGetMessage(regionName, mapPos[0]) if Essentials::VERSION.include?("20")
  return pbGetMessageFromHash(regionName, mapData.name.to_s) if Essentials::VERSION.include?("21")
end 

def convertIntegerOrFloat(number)
  number = number.to_i if number.to_i == number
  return number
end 

def convertOpacity(input)
  return (([0, [100, (input / 5.0).round * 5].min].max) * 2.55).round 
end 

def countSpeciesForms(hash)
  count = 0
  hash.each_value do |array|
    maxLength = 0
    array.each do |subArray|
      subArray.each do |data|
        maxLength = [maxLength, data.length].max
      end 
    end 
    count += maxLength
  end 
  return count
end 

def getSpeciesDexNumber(pokemon, region) 
  num = pbGetRegionalNumber(region, pokemon)
  if num <= 0
    region = -1
    nationalDex = [:NONE]
    GameData::Species.each_species { |s| nationalDex.push(s.species) }
    dexnum = nationalDex.index(pokemon) || 9999
  else 
    dexnum = num
    speciesData = GameData::Species.get(pokemon)
    if speciesData.form > 0
      dexnum += (speciesData.form.to_f / 10)
    end 
  end
  dexnum -= 1 if Settings::DEXES_WITH_OFFSETS.include?(region)
  return dexnum
end 

# Tracker Methods

def registerSpeciesSeen(species, gender, form, shiny)
  registerSpecies(SEEN, species, gender, form, shiny)
end 

def registerSpeciesCaught(species, gender, form, shiny)
  registerSpecies(CAUGHT, species, gender, form, shiny)
end 

def registerSpeciesDefeated(species, gender, form, shiny)
  registerSpecies(DEFEATED, species, gender, form, shiny)
end 

def registerSpecies(type, species, gender, form, shiny)
  speciesID, gender, shiny = validateSpecies(species, gender, shiny)
  mapID = $game_map.map_id
  return if [speciesID, gender, shiny].all?(&:nil?)
  spCounter, spMapCounter = getCounters(type, mapID)
  spCounter[speciesID] ||= [[[], []], [[], []]]
  spCounter[speciesID][gender][shiny][form] ||= 0
  spCounter[speciesID][gender][shiny][form] += 1
  spMapCounter[mapID] ||= {}
  spMapCounter[mapID][speciesID] ||= [[[], []], [[], []]]
  spMapCounter[mapID][speciesID][gender][shiny][form] ||= 0
  spMapCounter[mapID][speciesID][gender][shiny][form] += 1
end 

def validateSpecies(species, gender, shiny)
  speciesID = GameData::Species.try_get(species)&.species
  unless speciesID.nil?
    gender = 0 if !gender.nil? && gender >= 2 
    shiny = shiny ? 1 : 0
  end 
  return speciesID, gender, shiny
end 

def getCounters(type, mapID)
  counter1, counter2 =  case type
                        when SEEN
                          [$ArckyGlobal.seenSpeciesCount, $ArckyGlobal.seenSpeciesCountMap]
                        when CAUGHT
                          [$ArckyGlobal.caughtSpeciesCount, $ArckyGlobal.caughtSpeciesCountMap]
                        when DEFEATED
                          [$ArckyGlobal.defeatedSpeciesCount, $ArckyGlobal.defeatedSpeciesCountMap]
                        end 
  return counter1, counter2
end

def countSeenSpecies(species, gender = nil, form = nil, shiny = false)
  getCounterSpecies(SEEN, species, gender, form, shiny)    
end 

def countSeenSpeciesMap(map = nil, species = nil, gender = nil, form = nil, shiny = false)
  map = $game_map.map_id if map.nil?
  getCounterSpecies(SEEN, species, gender, form, shiny, map)
end 

def countCaughtSpecies(species, gender = nil, form = nil, shiny = false)
  getCounterSpecies(CAUGHT, species, gender, form, shiny)
end 

def countCaughtSpeciesMap(map = nil, species = nil, gender = nil, form = nil, shiny = false)
  map = $game_map.map_id if map.nil?
  getCounterSpecies(CAUGHT, species, gender, form, shiny, map)
end 

def countDefeatedSpecies(species, gender = nil, form = nil, shiny = false)
  getCounterSpecies(DEFEATED, species, gender, form, shiny)
end 

def countDefeatedSpeciesMap(map = nil, species = nil, gender = nil, form = nil, shiny = false)
  map = $game_map.map_id if map.nil?
  getCounterSpecies(DEFEATED, species, gender, form, shiny, map)
end 

def getCounterSpecies(type, species, gender, form, shiny, map = nil)
  speciesID, gender, shiny = validateSpecies(species, gender, shiny)
  spCounter, spMapCounter = getCounters(type, map)
  return 0 if spCounter.nil? || spMapCounter.nil?
  counter = map.nil? ? spCounter : spMapCounter[map]
  if speciesID.nil?
    if !counter.nil?
      return countSpeciesForms(counter)
    else
      return 0
    end
  end 
  return 0 if (counter.nil? || counter[speciesID].nil?)
  if gender && form && shiny # returns total amount of Species by given Gender, Form and Shininess.
    return counter[speciesID][gender][shiny][form] || 0
  elsif gender && form # returns total amount of Species by given Gender and Form.
    array = counter[speciesID][gender].map { |shinArr| shinArr[form] } || 0
  elsif gender # returns total amount of Species by given Gender.
    array = counter[speciesID][gender].flatten || 0
  elsif form # returns total amount of Species by given Form.
    array = counter[speciesID].map { |genArr| genArr.map { |shinArr| shinArr[form] } } || 0
  else # returns total amount of Species.
    array = counter[speciesID].flatten || 0
  end 
  return array.flatten.compact.sum
end 

if Essentials::VERSION.include?("20")
  module SaveData
    class Value
      def initialize(id, &block)
        validate id => Symbol, block => Proc
        @id = id
        @loaded = false
        @load_in_bootup = false
        @reset_on_new_game = false
        instance_eval(&block)
        raise "No save_value defined for save value #{id.inspect}" if @save_proc.nil?
        raise "No load_value defined for save value #{id.inspect}" if @load_proc.nil?
      end

      def reset_on_new_game
        @reset_on_new_game = true
      end
  
      def reset_on_new_game?
        return @reset_on_new_game
      end

      # Marks all values that aren't loaded on bootup as unloaded.
      def self.mark_values_as_unloaded
        @values.each do |value|
          value.mark_as_unloaded if !value.load_in_bootup? || value.reset_on_new_game?
        end
      end

      # Loads each {Value}'s new game value, if one is defined. Done when starting a
      # new game.
      def self.load_new_game_values
        @values.each do |value|
          value.load_new_game_value if value.has_new_game_proc? && (!value.loaded? || value.reset_on_new_game?)
        end
      end
    end 
  end 
end 