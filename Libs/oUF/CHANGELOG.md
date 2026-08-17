**Changes in 14.0.0:**

- _Adrian L Lange (69):_
    1. auras: Update wiki links
    2. auras: Use new unit state attribute
    3. enums: Remove unused Enum
    4. colors: Use a simple map instead of our custom Enum
    5. auras: Rewrite for 12.1
    6. core: Add new type of element registration
    7. blizzard: Use new rolesets
    8. core: Use new role sets
    9. core: Add shorthand for pausing/resuming all elements
    10. core: Add pausing/resuming of elements
    11. core: Reset nameplate elements on nameplate remove
    12. core: Rename unit-related state attributes
    13. castbar: Rearrange callback signatures
    14. tags: Rely on eventless global timer for updates
    15. core: Keep object element state internal
    16. core: Keep eventless state internal
    17. private: Use C_Secrets.CanCompareUnitTokens
    18. totems: Remove deprecated PostUpdate parameters
    19. totems: Add a note
    20. tags: Keep state internal
    21. tags: Use __owner like all other elements do
    22. tags: Use C_Secrets.CanCompareUnitTokens
    23. tags: Account for API secrecy
    24. summonindicator: Don't upvalue enums
    25. stagger: :broom:
    26. stagger: Keep state internal
    27. readycheckindicator: Remove deprecated options
    28. readycheckindicator: No need to expose state
    29. raidtargetindicator: Don't upvalue API
    30. raidroleindicator: Account for API secrecy
    31. pvpindicator: Account for API secrecy
    32. pvpclassificationindicator: :broom:
    33. powerprediction: Remove element
    34. power: Keep state internal
    35. power: Remove SetColorDisconnected method
    36. power: Don't upvalue enums
    37. power: Account for API secrecy
    38. portrait: Keep state internal
    39. portrait: Account for API secrecy
    40. phaseindicator: Prune the PostUpdate callback
    41. phaseindicator: Account for API secrecy
    42. leaderindicator: Account for API secrecy
    43. healthprediction: Remove element
    44. health: Keep state internal
    45. health: Remove SetColorDisconnected method
    46. health: Remove unnecessarily exposed state
    47. health: Account for API secrecy
    48. grouproleindicator: Swap to enum API variant
    49. grouproleindicator: Account for API secrecy
    50. classpower: Rewrite UpdateColor/ColorPath to match other elements
    51. classpower: Expose hasCurChanged too for good measure
    52. classpower: Keep state internal
    53. classpower: Don't upvalue enums
    54. castbar: Use new delay return for casts
    55. castbar: Don't color Delay text
    56. castbar: Use a binding for Time, and split out Delay
    57. castbar: Remove invalid payload
    58. castbar: :broom:
    59. castbar: Add support for global cast bar
    60. castbar: Keep state internal
    61. castbar: Fix empowered end time calculations
    62. assistantindicator: Account for API secrecy
    63. alternativepower: Keep state internal
    64. alternativepower: Remove unnecessarily exposed state
    65. alternativepower: Don't upvalue enums
    66. additionalpower: Keep state internal
    67. additionalpower: Remove unnecessarily exposed state
    68. core: Hide non-unit nameplates ([#866](https://github.com/oUF-wow/oUF/issues/866))
    69. castbar: Reset before we start a cast ([#867](https://github.com/oUF-wow/oUF/issues/867))
- _dependabot[bot] (1):_
    1. build(deps): bump actions/checkout from 6 to 7 ([#869](https://github.com/oUF-wow/oUF/issues/869))
- _github-actions[bot] (1):_
    1. Update Interface version ([#862](https://github.com/oUF-wow/oUF/issues/862))
- 43 files changed, 1212 insertions(+), 2097 deletions(-)

