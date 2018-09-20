---
    title: cache lru
---

### lru

```golang
package lru

//LRU Cache
import (
    "container/list"
)

type CacheNode struct {
    key   interface{}
    value interface{}
}

func NewCacheNode(k, v interface{}) *CacheNode {
    return &CacheNode{k, v}
}

type Lru struct {
    capacity int
    dlist    *list.List
    cacheMap map[interface{}]*list.Element
}

func NewLru(cap int) *Lru {
    return &Lru{
        capacity: cap,
        dlist:    list.New(),
        cacheMap: make(map[interface{}]*list.Element),
    }
}

func (lru *Lru) Size() int {
    return lru.dlist.Len()
}

func (lru *Lru) Set(k, v interface{}) error {
    if lru.dlist == nil {
        return error.New("lrucache need init")
    }

    //key exist, movetoFront, update value
    if pElement, ok := lru.cacheMap[k]; ok {
      lru.dlist.MoveToFront(pElement)
      pElement.Value.(*CacheNode).Value = v
      return nil
  }

  //not exist
  newElement := lru.dlist.PushFront(&CacheNode{k, v})
  lru.cacheMap[k] = newElement

  if lru.dlist.Len() > lru.capacity {
      lastElement := lru.dlist.Back()
      if lastElement == nil {
          return nil
      }

      cacheNode := lastElement.Value.(*CacheNode)
      delete(lru.cacheMap, cacheNode.key)
      lru.dlist.Remove(lastElement)
  }
  return nil
}

func (lru *Lru) Get(k interface{}) (v interface{}, err error) {
  if lru.cacheMap == nil {
      return v, errors.New("LRUCache need init")
  }

  if pElement, ok := lru.cacheMap[k]; ok {
      lru.dlist.MoveToFront(pElement)
      return pElement.Value.(*CacheNode).Value, nil
  }
  return v, nil
}

func (lru *LRUCache) Remove(k interface{}) bool {
  if lru.cacheMap == nil {
      return false
  }

  if pElement, ok := lru.cacheMap[k]; ok {
      cacheNode := pElement.Value.(*CacheNode)
      delete(lru.cacheMap, cacheNode.Key)
      lru.dlist.Remove(pElement)
      return true
  }
  return false
}
```
