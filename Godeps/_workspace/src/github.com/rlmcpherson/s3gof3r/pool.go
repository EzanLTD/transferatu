package s3gof3r

import (
	"bytes"
	"container/list"
	"time"
)

type q_buf struct {
	when   time.Time
	buffer *bytes.Buffer
}

type bp struct {
	makes int
	get   chan *bytes.Buffer
	give  chan *bytes.Buffer
	quit  chan bool
}

func makeBuffer(size int64) []byte {
	return make([]byte, 0, size)
}

func newBufferPool(bufsz int64) (np *bp) {
	np = new(bp)
	np.get = make(chan *bytes.Buffer)
	np.give = make(chan *bytes.Buffer)
	np.quit = make(chan bool)
	go func() {
		q := new(list.List)
		for {
			if q.Len() == 0 {
				size := bufsz + 100*kb // allocate overhead to avoid slice growth
				q.PushFront(q_buf{when: time.Now(), buffer: bytes.NewBuffer(makeBuffer(int64(size)))})
				np.makes++
			}

			e := q.Front()

			timeout := time.NewTimer(time.Minute)
			select {
			case b := <-np.give:
				timeout.Stop()
				q.PushFront(q_buf{when: time.Now(), buffer: b})

			case np.get <- e.Value.(q_buf).buffer:
				timeout.Stop()
				q.Remove(e)

			case <-timeout.C:
				// free unused buffers
				e := q.Front()
				for e != nil {
					n := e.Next()
					if time.Since(e.Value.(q_buf).when) > time.Minute {
						q.Remove(e)
						e.Value = nil
					}
					e = n
				}
			case <-np.quit:
				return
			}
		}

	}()
	return np
}
