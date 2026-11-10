# Address Decoder Datapath & Field Extraction

```mermaid
flowchart TD
    ADDR["32-bit Memory Address: address[31:0]"]

    subgraph Extraction["Field Extraction"]
        TAG["tag[21:0] = address[31:10]<br/>(22 bits)"]
        IDX["index[5:0] = address[9:4]<br/>(6 bits -> 64 lines)"]
        BYTE["byte_offset[3:0] = address[3:0]<br/>(4 bits -> 16 bytes/line)"]
        WORD["word_offset[1:0] = address[3:2]<br/>(2 bits -> 4 words/line)"]
    end

    ADDR --> TAG
    ADDR --> IDX
    ADDR --> BYTE
    ADDR --> WORD

    subgraph TagComparator["Tag Comparator & Hit Qualification"]
        STAG["stored_tag[21:0]<br/>(from cache line)"]
        SVAL["stored_valid<br/>(from cache line)"]
        EQ{"stored_tag == tag"}
        TMATCH["tag_match (1 bit)"]
        AND_GATE{"AND"}
        HIT["hit (1 bit)"]
    end

    TAG --> EQ
    STAG --> EQ
    EQ --> TMATCH
    TMATCH --> AND_GATE
    SVAL --> AND_GATE
    AND_GATE --> HIT
```

### Signal Summary
- **Inputs**:
  - `address[31:0]`: CPU / memory request address (32-bit aligned, `[1:0] == 2'b00`).
  - `stored_tag[21:0]`: 22-bit tag stored in cache storage at `lookup_index`.
  - `stored_valid`: Valid flag of the cache line at `lookup_index`.
- **Outputs**:
  - `tag[21:0]`: Tag field passed to controller.
  - `index[5:0]`: Cache line index forwarded to cache storage `lookup_index`.
  - `byte_offset[3:0]`: Byte offset within line.
  - `word_offset[1:0]`: Word offset forwarded to cache storage `lookup_word_offset`.
  - `tag_match`: Equality indicator between `stored_tag` and `tag`.
  - `hit`: High only when both `stored_valid` and `tag_match` are asserted.

