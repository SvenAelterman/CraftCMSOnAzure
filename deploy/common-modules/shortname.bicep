/*
 * Creates a short name for the given structure and values that is no longer than the maximum specified length
 * How this is shorter than the standard naming convention
 * - Saves usually 1 character on the sequence (01 vs. 1)
 * - Saves a few characters in the location name (eastus vs. eus)
 * - Takes only the first character of the environment (prod = p, demo or dev = d, test = t)
 * - Ensures the max length does not exceed the specified value
 */

param namingConvention string
param location string
param resourceType string
param environment string
param workloadName string
param sequence int
param removeHyphens bool = false

// 24 is for Key Vault
param maxLength int = 24

// LATER: Add a comprehensive list, but there appears to be no authoritative source
// https://github.com/MicrosoftDocs/azure-docs/issues/61803
// https://github.com/aznamingtool/AzureNamingTool/blob/7a2242d24572ee7204bd1514bd5ed74c870c6722/repository/resourcelocations.json
var shortLocations = {
  eastus: 'eus'
  eastus2: 'eus2'
}

// Translate the regular location value to a shorter value
var shortLocationValue = shortLocations[location]
var shortNameAnyLength = replace(replace(replace(replace(replace(namingConvention, '{env}', take(environment, 1)), '{loc}', shortLocationValue), '{seq}', string(sequence)), '{wloadname}', workloadName), '{rtype}', resourceType)
var shortNameAnyLengthHyphensProcessed = removeHyphens ? replace(shortNameAnyLength, '-', '') : shortNameAnyLength

output shortName string = take(shortNameAnyLengthHyphensProcessed, maxLength)
