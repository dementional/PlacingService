type ParamsInstance = RaycastParams | OverlapParams
type ParamsConfig = {
	IncludeInstances: { Instance }?,
	ExcludeInstances: { Instance }?,

	RespectCanCollide: boolean?,
	CollisionGroup: string?,
	BruteForceAllSlow: boolean?
}

export type Params = {
	RespectCanCollide: boolean,
	CollisionGroup: string,
	BruteForceAllSlow: boolean,
	
	Include: (params: Params, instances: Instance | { Instance }) -> (),
	Exclude: (params: Params, instances: Instance | { Instance }) -> (),
	RemoveInclude: (params: Params, instances: Instance | { Instance }) -> (),
	RemoveExclude: (params: Params, instances: Instance | { Instance }) -> (),
	ClearInclude: (params: Params) -> (),
	ClearExclude: (params: Params) -> (),
}

local ParamsBuilder = {}
ParamsBuilder.__index = ParamsBuilder

function ParamsBuilder.new(paramsInstance: ParamsInstance?): Params
	local params: Params = setmetatable({
		_IncludeInstances = {},
		_ExcludeInstances = {},
		
		RespectCanCollide = false,
		CollisionGroup = "Default",
		BruteForceAllSlow = false,
		
		_ParamsInstance = paramsInstance
	}, ParamsBuilder)
	
	return params
end

function ParamsBuilder.fromConfig(
	paramsInstance: ParamsInstance,
	paramsConfig: ParamsConfig
): Params
	local params: Params = ParamsBuilder.new(paramsInstance)
	
	if paramsConfig.IncludeInstances then
		params._IncludeInstances = table.clone(paramsConfig.IncludeInstances) end

	if paramsConfig.ExcludeInstances then
		params._ExcludeInstances = table.clone(paramsConfig.ExcludeInstances) end

	if paramsConfig.RespectCanCollide ~= nil then
		params.RespectCanCollide = paramsConfig.RespectCanCollide end

	if paramsConfig.CollisionGroup then
		params.CollisionGroup = paramsConfig.CollisionGroup end

	if paramsConfig.BruteForceAllSlow ~= nil then
		params.BruteForceAllSlow = paramsConfig.BruteForceAllSlow end
	
	return params
end

function ParamsBuilder._Rebuild(params: Params)
	local paramsInstance: RaycastParams | OverlapParams = params._ParamsInstance
	
	paramsInstance.IncludeInstances = params._IncludeInstances
	paramsInstance.ExcludeInstances = params._ExcludeInstances
	
	paramsInstance.RespectCanCollide = params.RespectCanCollide
	paramsInstance.CollisionGroup = params.CollisionGroup
	paramsInstance.BruteForceAllSlow = params.BruteForceAllSlow
end

function ParamsBuilder.Include(params: Params, instances: Instance | { Instance })
	if typeof(instances) ~= "table" then
		instances = { instances } end

	for _, instance: Instance in instances do
		local index: number? = table.find(params._IncludeInstances, instance)
		if index then continue end

		table.insert(params._IncludeInstances, instance)
	end
	
	params:_Rebuild()
end

function ParamsBuilder.Exclude(params: Params, instances: { Instance })
	if typeof(instances) ~= "table" then
		instances = { instances } end

	for _, instance: Instance in instances do
		local index: number? = table.find(params._ExcludeInstances, instance)
		if index then continue end

		table.insert(params._ExcludeInstances, instance)
	end
	
	params:_Rebuild()
end

function ParamsBuilder.RemoveInclude(params: Params, instances: Instance | { Instance })
	if typeof(instances) ~= "table" then
		instances = { instances } end

	for index: number = #params._IncludeInstances, 1, -1 do
		local instance: Instance = params._IncludeInstances[index]
		local otherIndex: number = table.find(instances, instance)

		if not otherIndex then continue end

		table.remove(params._IncludeInstances, index)
	end

	params:_Rebuild()
end

function ParamsBuilder.RemoveExclude(params: Params, instances: { Instance })
	if typeof(instances) ~= "table" then
		instances = { instances } end
	
	for index: number = #params._ExcludeInstances, 1, -1 do
		local instance: Instance = params._ExcludeInstances[index]
		local otherIndex: number = table.find(instances, instance)
		
		if not otherIndex then continue end
		
		table.remove(params._ExcludeInstances, index)
	end
	
	params:_Rebuild()
end

function ParamsBuilder.ClearInclude(params: Params)
	table.clear(params._IncludeInstances)
	params:_Rebuild(params)
end

function ParamsBuilder.ClearExclude(params: Params)
	table.clear(params._ExcludeInstances)
	params:_Rebuild(params)
end

return ParamsBuilder